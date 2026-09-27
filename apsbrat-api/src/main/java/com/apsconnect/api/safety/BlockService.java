package com.apsconnect.api.safety;

import com.apsconnect.api.circle.CircleCache;
import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.connection.ConnectionRepository;
import com.apsconnect.api.connection.ConnectionStatus;
import com.apsconnect.api.user.PersonDto;
import com.apsconnect.api.user.PersonService;
import com.apsconnect.api.user.User;
import com.apsconnect.api.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class BlockService {

    private final UserBlockRepository blockRepository;
    private final UserRepository userRepository;
    private final PersonService personService;
    private final ConnectionRepository connectionRepository;
    private final CircleCache circleCache;

    @Transactional
    public void block(UUID currentUserId, UUID targetUserId) {
        if (currentUserId.equals(targetUserId)) {
            throw new AppException("Cannot block yourself", HttpStatus.BAD_REQUEST);
        }
        if (blockRepository.existsByBlocker_IdAndBlocked_Id(currentUserId, targetUserId)) {
            return;
        }
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new AppException("User not found", HttpStatus.NOT_FOUND));
        UserBlock block = new UserBlock();
        block.setBlocker(userRepository.getReferenceById(currentUserId));
        block.setBlocked(target);
        blockRepository.save(block);

        // A block ends whatever was live between the two people.
        connectionRepository.findBetween(currentUserId, targetUserId).stream()
                .filter(c -> c.getStatus().isLive())
                .forEach(c -> {
                    c.setStatus(ConnectionStatus.REMOVED);
                    connectionRepository.save(c);
                });
        circleCache.evictUser(currentUserId);
        circleCache.evictUser(targetUserId);
    }

    @Transactional
    public void unblock(UUID currentUserId, UUID targetUserId) {
        blockRepository.deleteByBlocker_IdAndBlocked_Id(currentUserId, targetUserId);
    }

    @Transactional(readOnly = true)
    public List<PersonDto> myBlocks(UUID currentUserId) {
        List<User> blocked = blockRepository.findAllByBlocker_IdOrderByCreatedAtDesc(currentUserId).stream()
                .map(UserBlock::getBlocked)
                .toList();
        return personService.toPeople(blocked);
    }
}
