package com.apsconnect.api.community;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import com.apsconnect.api.common.response.CursorPage;
import com.apsconnect.api.common.util.CursorSupport;
import com.apsconnect.api.media.ImageUploadService;
import com.apsconnect.api.notification.NotificationRef;
import com.apsconnect.api.notification.NotificationService;
import com.apsconnect.api.notification.NotificationType;
import com.apsconnect.api.safety.UserBlockRepository;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Text posts, likes and comments inside communities (course Chapters 6, 7 and 9). */
@Service
@RequiredArgsConstructor
public class PostService {

    private static final int MAX_POSTS_PER_HOUR = 10;
    private static final int MAX_COMMENTS_PER_HOUR = 60;
    /** Photos per post (the slider). */
    public static final int MAX_PHOTOS = 10;
    static final int MAX_PINNED = 3;
    /** Earliest year a memory can be from (the first Army Public Schools). */
    static final int FIRST_MEMORY_YEAR = 1950;
    /** Popular ranks posts from this many days back, so it keeps rotating. */
    static final int POPULAR_DAYS = 30;
    /** Stands in for "nobody" so NOT IN (...) is never given an empty list. */
    private static final UUID NOBODY = new UUID(0, 0);

    private final PostRepository postRepository;
    private final PostLikeRepository likeRepository;
    private final CommentRepository commentRepository;
    private final CommunityRepository communityRepository;
    private final CommunityService communityService;
    private final UserRepository userRepository;
    private final PersonService personService;
    private final UserBlockRepository blockRepository;
    private final NotificationService notificationService;
    private final StringRedisTemplate redis;
    private final ImageUploadService imageUploadService;
    private final CommunityEventService eventService;
    private final CommunityEventRepository eventRepository;

    // ── Posts (Chapter 6) ──────────────────────────────────────────────────

    @Transactional
    public PostDto create(UUID userId, UUID communityId, CreatePostRequest request) {
        Community community = communityService.requireMember(userId, communityId);
        rateLimit("posts:" + userId, MAX_POSTS_PER_HOUR, "You're posting a lot. Try again in a little while.");

        String body = request.body() == null ? "" : request.body().trim();
        // Each photo must be one this person uploaded; repeats are dropped, order kept.
        List<String> photos = (request.imageUrls() == null ? List.<String>of() : request.imageUrls()).stream()
                .map(url -> imageUploadService.requireOwnUpload(userId, url))
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();
        if (photos.size() > MAX_PHOTOS) {
            throw new AppException("A post can have at most " + MAX_PHOTOS + " photos", HttpStatus.BAD_REQUEST);
        }
        if (body.isEmpty() && photos.isEmpty()) {
            throw new AppException("Write something or add a photo", HttpStatus.BAD_REQUEST);
        }
        boolean memory = request.memoryYear() != null || request.memoryCategory() != null;
        if (memory) {
            if (community.getType() != CommunityType.SCHOOL) {
                throw new AppException("Memories are only for school communities", HttpStatus.BAD_REQUEST);
            }
            if (request.memoryYear() == null || request.memoryCategory() == null) {
                throw new AppException("A memory needs both a year and a category", HttpStatus.BAD_REQUEST);
            }
            if (request.memoryYear() < FIRST_MEMORY_YEAR || request.memoryYear() > LocalDate.now().getYear()) {
                throw new AppException("Pick a year between " + FIRST_MEMORY_YEAR + " and now", HttpStatus.BAD_REQUEST);
            }
            if (photos.isEmpty()) {
                throw new AppException("Add at least one photo to share a memory", HttpStatus.BAD_REQUEST);
            }
        }

        Post post = new Post();
        post.setCommunityId(communityId);
        post.setAuthorId(userId);
        post.setBody(body);
        post.setImageUrls(new java.util.ArrayList<>(photos));
        post.setEventId(request.eventId() == null ? null
                : eventService.requireTaggable(request.eventId(), communityId).getId());
        post.setMemoryYear(request.memoryYear());
        post.setMemoryCategory(request.memoryCategory());
        return toDtos(List.of(postRepository.save(post)), userId).get(0);
    }

    /**
     * A community's posts, "latest" (newest first, timestamp cursor) or "popular"
     * (score over the last POPULAR_DAYS, offset cursor). Pinned posts lead the first page.
     */
    @Transactional(readOnly = true)
    public CursorPage<PostDto> list(UUID userId, UUID communityId, String sort, String cursor, int limit) {
        communityService.requireReadable(userId, communityId);
        boolean firstPage = cursor == null || cursor.isBlank();
        Set<UUID> hidden = hiddenAuthors(userId);

        CursorPage<PostDto> rest;
        if ("popular".equals(sort)) {
            int size = CursorSupport.clampLimit(limit);
            int offset;
            try {
                offset = firstPage ? 0 : Integer.parseInt(cursor);
            } catch (NumberFormatException e) {
                offset = -1;
            }
            if (offset < 0) {
                throw new AppException("Invalid cursor", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
            }
            List<Post> rows = postRepository.findPopularPage(communityId,
                    LocalDateTime.now().minusDays(POPULAR_DAYS), hidden, size + 1, offset);
            boolean hasMore = rows.size() > size;
            if (hasMore) {
                rows = rows.subList(0, size);
            }
            rest = CursorPage.of(toDtos(rows, userId), hasMore ? String.valueOf(offset + size) : null, hasMore);
        } else if ("latest".equals(sort)) {
            rest = page(userId, List.of(communityId), false, cursor, limit);
        } else {
            throw new AppException("sort must be latest or popular", HttpStatus.BAD_REQUEST);
        }

        if (!firstPage) {
            return rest;
        }
        List<Post> pinned = postRepository
                .findByCommunityIdAndStatusAndPinnedAtIsNotNullOrderByPinnedAtDesc(communityId, ContentStatus.ACTIVE)
                .stream().filter(p -> !hidden.contains(p.getAuthorId())).toList();
        if (pinned.isEmpty()) {
            return rest;
        }
        List<PostDto> items = new ArrayList<>(toDtos(pinned, userId));
        items.addAll(rest.items());
        return CursorPage.of(items, rest.nextCursor(), rest.hasMore());
    }

    /** Home: the newest posts across every community I've joined (Chapter 9). */
    @Transactional(readOnly = true)
    public CursorPage<PostDto> homeFeed(UUID userId, String cursor, int limit) {
        List<UUID> mine = communityService.myCommunityIds(userId);
        if (mine.isEmpty()) {
            return CursorPage.of(List.of(), null, false);
        }
        return page(userId, mine, true, cursor, limit);
    }

    /**
     * The Memories gallery, grouped by year (newest year first); optionally one
     * year and/or category. The cursor is the next page number.
     */
    @Transactional(readOnly = true)
    public CursorPage<PostDto> memories(UUID userId, UUID communityId, Short year, MemoryCategory category,
                                        String cursor, int limit) {
        communityService.requireReadable(userId, communityId);
        int page;
        try {
            page = cursor == null || cursor.isBlank() ? 0 : Integer.parseInt(cursor);
        } catch (NumberFormatException e) {
            page = -1;
        }
        if (page < 0) {
            throw new AppException("Invalid cursor", HttpStatus.BAD_REQUEST, ErrorCode.BAD_REQUEST);
        }
        var slice = postRepository.findMemoryPage(communityId, year, category, ContentStatus.ACTIVE,
                hiddenAuthors(userId), PageRequest.of(page, CursorSupport.clampLimit(limit)));
        return CursorPage.of(toDtos(slice.getContent(), userId),
                slice.hasNext() ? String.valueOf(page + 1) : null, slice.hasNext());
    }

    /** Years that have memories, for the gallery's year filter. */
    @Transactional(readOnly = true)
    public List<Short> memoryYears(UUID userId, UUID communityId) {
        communityService.requireReadable(userId, communityId);
        return postRepository.findMemoryYears(communityId, ContentStatus.ACTIVE);
    }

    /** Posts shared from an event (its photos), newest first. */
    @Transactional(readOnly = true)
    public CursorPage<PostDto> eventPosts(UUID userId, UUID eventId, String cursor, int limit) {
        eventService.readableEvent(userId, eventId);
        int size = CursorSupport.clampLimit(limit);
        LocalDateTime before = CursorSupport.decode(cursor);
        List<Post> rows = postRepository.findEventPage(eventId, ContentStatus.ACTIVE,
                before == null ? LocalDateTime.now().plusMinutes(1) : before,
                hiddenAuthors(userId), PageRequest.of(0, size + 1));
        return timeCursorPage(rows, size, userId);
    }

    @Transactional(readOnly = true)
    public PostDto get(UUID userId, UUID postId) {
        return toDtos(List.of(readablePost(userId, postId)), userId).get(0);
    }

    /** Soft delete: the post is kept as REMOVED so a mistake can be undone. */
    @Transactional
    public void delete(UUID userId, UUID postId) {
        Post post = postRepository.findById(postId)
                .filter(p -> p.getStatus() != ContentStatus.REMOVED)
                .orElseThrow(PostService::postNotFound);
        if (!canModerate(userId, post.getAuthorId(), post.getCommunityId())) {
            throw new AppException("You can't delete this post", HttpStatus.FORBIDDEN);
        }
        post.setStatus(ContentStatus.REMOVED);
    }

    /** Owners pin in their own communities, staff anywhere; at most MAX_PINNED per community. */
    @Transactional
    public PostDto setPinned(UUID userId, UUID postId, boolean pinned) {
        Post post = readablePost(userId, postId);
        if (!communityService.ownedCommunityIds(userId).contains(post.getCommunityId())
                && !communityService.isStaff(userId)) {
            throw new AppException("You can't pin posts here", HttpStatus.FORBIDDEN);
        }
        if (pinned && post.getPinnedAt() == null) {
            if (postRepository.countByCommunityIdAndStatusAndPinnedAtIsNotNull(
                    post.getCommunityId(), ContentStatus.ACTIVE) >= MAX_PINNED) {
                throw new AppException("You can pin up to " + MAX_PINNED + " posts. Unpin one first.",
                        HttpStatus.BAD_REQUEST);
            }
            post.setPinnedAt(LocalDateTime.now());
        } else if (!pinned) {
            post.setPinnedAt(null);
        }
        return toDtos(List.of(post), userId).get(0);
    }

    // ── Likes (Chapter 7)─────────────────────────────────────────────────

    /** Like. Repeating it changes nothing: the count only moves when a row is really added. */
    @Transactional
    public PostDto like(UUID userId, UUID postId) {
        Post post = interactablePost(userId, postId);
        if (likeRepository.insertIfAbsent(post.getId(), userId) == 1) {
            postRepository.addToLikeCount(post.getId(), 1);
        }
        return get(userId, postId);
    }

    @Transactional
    public PostDto unlike(UUID userId, UUID postId) {
        Post post = interactablePost(userId, postId);
        if (likeRepository.deleteLike(post.getId(), userId) == 1) {
            postRepository.addToLikeCount(post.getId(), -1);
        }
        return get(userId, postId);
    }

    // ── Comments (Chapter 7) ──────────────────────────────────────────────

    /** Oldest first, like a conversation. */
    @Transactional(readOnly = true)
    public CursorPage<CommentDto> comments(UUID userId, UUID postId, String cursor, int limit) {
        Post post = readablePost(userId, postId);
        int size = CursorSupport.clampLimit(limit);
        LocalDateTime after = CursorSupport.decode(cursor);
        List<Comment> rows = commentRepository.findPage(post.getId(), ContentStatus.ACTIVE,
                after == null ? LocalDateTime.of(1970, 1, 1, 0, 0) : after,
                hiddenAuthors(userId), PageRequest.of(0, size + 1));

        boolean hasMore = rows.size() > size;
        if (hasMore) {
            rows = rows.subList(0, size);
        }
        String next = hasMore ? CursorSupport.encode(rows.get(rows.size() - 1).getCreatedAt()) : null;
        return CursorPage.of(toCommentDtos(rows, userId, post), next, hasMore);
    }

    @Transactional
    public CommentDto addComment(UUID userId, UUID postId, CreateCommentRequest request) {
        Post post = interactablePost(userId, postId);
        rateLimit("comments:" + userId, MAX_COMMENTS_PER_HOUR, "You're commenting a lot. Try again in a little while.");

        Comment comment = new Comment();
        comment.setPostId(post.getId());
        comment.setAuthorId(userId);
        comment.setBody(request.body().trim());
        comment = commentRepository.save(comment);
        postRepository.addToCommentCount(post.getId(), 1);

        if (!post.getAuthorId().equals(userId)) {
            User me = userRepository.getReferenceById(userId);
            notificationService.create(post.getAuthorId(), NotificationType.GENERAL, "New comment",
                    displayName(userId) + " commented on your post", me, NotificationRef.POST, post.getId());
        }
        return toCommentDtos(List.of(comment), userId, post).get(0);
    }

    @Transactional
    public void deleteComment(UUID userId, UUID commentId) {
        Comment comment = commentRepository.findById(commentId)
                .filter(c -> c.getStatus() != ContentStatus.REMOVED)
                .orElseThrow(() -> new AppException("Comment not found", HttpStatus.NOT_FOUND));
        Post post = postRepository.findById(comment.getPostId()).orElseThrow(PostService::postNotFound);
        if (!canModerate(userId, comment.getAuthorId(), post.getCommunityId())) {
            throw new AppException("You can't delete this comment", HttpStatus.FORBIDDEN);
        }
        setCommentStatus(comment, ContentStatus.REMOVED);
    }

    // ── Moderation hooks (Chapter 8) ──────────────────────────────────────

    /** Hides a post after reports; HIDDEN posts disappear for everyone until staff review. */
    @Transactional
    public void hidePost(UUID postId) {
        postRepository.findById(postId)
                .filter(p -> p.getStatus() == ContentStatus.ACTIVE)
                .ifPresent(p -> p.setStatus(ContentStatus.HIDDEN));
    }

    @Transactional
    public void hideComment(UUID commentId) {
        commentRepository.findById(commentId)
                .filter(c -> c.getStatus() == ContentStatus.ACTIVE)
                .ifPresent(c -> setCommentStatus(c, ContentStatus.HIDDEN));
    }

    /** Staff undo of a hide or removal. */
    @Transactional
    public void restorePost(UUID postId) {
        Post post = postRepository.findById(postId).orElseThrow(PostService::postNotFound);
        post.setStatus(ContentStatus.ACTIVE);
    }

    @Transactional
    public void restoreComment(UUID commentId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new AppException("Comment not found", HttpStatus.NOT_FOUND));
        setCommentStatus(comment, ContentStatus.ACTIVE);
    }

    /** A report must point at a post or comment the reporter can actually see. */
    @Transactional(readOnly = true)
    public void requireReportable(UUID userId, boolean isPost, UUID id) {
        Comment comment = isPost ? null : commentRepository.findById(id)
                .filter(c -> c.getStatus() == ContentStatus.ACTIVE)
                .orElseThrow(() -> new AppException("Reported item not found", HttpStatus.NOT_FOUND));
        Post post = readablePost(userId, isPost ? id : comment.getPostId());
        UUID authorId = isPost ? post.getAuthorId() : comment.getAuthorId();
        if (authorId.equals(userId)) {
            throw new AppException("You can't report your own " + (isPost ? "post" : "comment"),
                    HttpStatus.BAD_REQUEST);
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private CursorPage<PostDto> page(UUID userId, List<UUID> communityIds, boolean includePinned,
                                     String cursor, int limit) {
        int size = CursorSupport.clampLimit(limit);
        LocalDateTime before = CursorSupport.decode(cursor);
        List<Post> rows = postRepository.findPage(communityIds, ContentStatus.ACTIVE,
                before == null ? LocalDateTime.now().plusMinutes(1) : before,
                hiddenAuthors(userId), includePinned, PageRequest.of(0, size + 1));
        return timeCursorPage(rows, size, userId);
    }

    /** rows were fetched as size + 1, newest first; the extra row only says "there's more". */
    private CursorPage<PostDto> timeCursorPage(List<Post> rows, int size, UUID userId) {
        boolean hasMore = rows.size() > size;
        if (hasMore) {
            rows = rows.subList(0, size);
        }
        String next = hasMore ? CursorSupport.encode(rows.get(rows.size() - 1).getCreatedAt()) : null;
        return CursorPage.of(toDtos(rows, userId), next, hasMore);
    }

    /** An ACTIVE post I'm allowed to read, by someone I haven't blocked (or been blocked by). */
    private Post readablePost(UUID userId, UUID postId) {
        Post post = postRepository.findById(postId)
                .filter(p -> p.getStatus() == ContentStatus.ACTIVE)
                .orElseThrow(PostService::postNotFound);
        if (blockRepository.existsBetween(userId, post.getAuthorId())) {
            throw postNotFound();
        }
        communityService.requireReadable(userId, post.getCommunityId());
        return post;
    }

    /** Readable, and I'm a member (to like or comment). */
    private Post interactablePost(UUID userId, UUID postId) {
        Post post = readablePost(userId, postId);
        communityService.requireMember(userId, post.getCommunityId());
        return post;
    }

    private boolean canModerate(UUID userId, UUID authorId, UUID communityId) {
        return authorId.equals(userId)
                || communityService.ownedCommunityIds(userId).contains(communityId)
                || communityService.isStaff(userId);
    }

    /** People whose posts I never see: those I blocked and those who blocked me. */
    private Set<UUID> hiddenAuthors(UUID userId) {
        Set<UUID> ids = new HashSet<>(blockRepository.findBlockedIdsInvolving(userId));
        ids.add(NOBODY);
        return ids;
    }

    /** comment_count counts ACTIVE comments only, so it moves when a comment enters or leaves ACTIVE. */
    private void setCommentStatus(Comment comment, ContentStatus status) {
        boolean wasActive = comment.getStatus() == ContentStatus.ACTIVE;
        boolean isActive = status == ContentStatus.ACTIVE;
        comment.setStatus(status);
        commentRepository.saveAndFlush(comment);
        if (wasActive != isActive) {
            postRepository.addToCommentCount(comment.getPostId(), isActive ? 1 : -1);
        }
    }

    /**
     * Builds a whole page of posts with a fixed number of queries, whatever the
     * page size: authors, community names, my likes and my owned communities
     * are each loaded once.
     */
    private List<PostDto> toDtos(List<Post> posts, UUID viewerId) {
        if (posts.isEmpty()) {
            return List.of();
        }
        Map<UUID, PersonDto> authors = people(posts.stream().map(Post::getAuthorId).toList());
        Map<UUID, String> communityNames = communityRepository
                .findAllById(posts.stream().map(Post::getCommunityId).distinct().toList()).stream()
                .collect(Collectors.toMap(Community::getId, Community::getName));
        Set<UUID> liked = new HashSet<>(likeRepository.findLikedPostIds(viewerId, posts.stream().map(Post::getId).toList()));
        Set<UUID> owned = communityService.ownedCommunityIds(viewerId);
        boolean staff = communityService.isStaff(viewerId);
        Map<UUID, String> eventTitles = eventRepository
                .findAllById(posts.stream().map(Post::getEventId).filter(java.util.Objects::nonNull).distinct().toList())
                .stream().collect(Collectors.toMap(CommunityEvent::getId, CommunityEvent::getTitle));

        return posts.stream()
                .filter(p -> authors.containsKey(p.getAuthorId()))
                .map(p -> new PostDto(
                        p.getId(),
                        p.getCommunityId(),
                        communityNames.get(p.getCommunityId()),
                        authors.get(p.getAuthorId()),
                        p.getBody(),
                        p.getImageUrls(),
                        p.getLikeCount(),
                        p.getCommentCount(),
                        liked.contains(p.getId()),
                        p.getAuthorId().equals(viewerId) || owned.contains(p.getCommunityId()) || staff,
                        p.getPinnedAt() != null,
                        owned.contains(p.getCommunityId()) || staff,
                        p.getEventId(),
                        eventTitles.get(p.getEventId()),
                        p.getMemoryYear(),
                        p.getMemoryCategory(),
                        p.getCreatedAt()))
                .toList();
    }

    private List<CommentDto> toCommentDtos(List<Comment> comments, UUID viewerId, Post post) {
        if (comments.isEmpty()) {
            return List.of();
        }
        Map<UUID, PersonDto> authors = people(comments.stream().map(Comment::getAuthorId).toList());
        boolean moderator = communityService.ownedCommunityIds(viewerId).contains(post.getCommunityId())
                || communityService.isStaff(viewerId);
        return comments.stream()
                .filter(c -> authors.containsKey(c.getAuthorId()))
                .map(c -> new CommentDto(c.getId(), c.getPostId(), authors.get(c.getAuthorId()), c.getBody(),
                        moderator || c.getAuthorId().equals(viewerId), c.getCreatedAt()))
                .toList();
    }

    private Map<UUID, PersonDto> people(List<UUID> ids) {
        return personService.toPeople(userRepository.findAllById(ids.stream().distinct().toList())).stream()
                .collect(Collectors.toMap(PersonDto::id, Function.identity()));
    }

    private String displayName(UUID userId) {
        return userRepository.findById(userId)
                .map(u -> u.getFullName() == null || u.getFullName().isBlank() ? "Someone" : u.getFullName())
                .orElse("Someone");
    }

    /** At most [max] actions per hour per person, counted in Redis. */
    private void rateLimit(String key, int max, String message) {
        String redisKey = "ratelimit:" + key;
        Long count = redis.opsForValue().increment(redisKey);
        if (count != null && count == 1L) {
            redis.expire(redisKey, Duration.ofHours(1));
        }
        if (count != null && count > max) {
            throw new AppException(message, HttpStatus.TOO_MANY_REQUESTS, ErrorCode.RATE_LIMITED);
        }
    }

    private static AppException postNotFound() {
        return new AppException("Post not found", HttpStatus.NOT_FOUND);
    }
}
