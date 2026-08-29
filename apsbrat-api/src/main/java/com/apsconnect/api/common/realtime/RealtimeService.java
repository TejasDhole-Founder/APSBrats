package com.apsconnect.api.common.realtime;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

/**
 * Fans realtime chat events out across every API instance via a Redis pub/sub
 * channel, then delivers them to the STOMP sessions connected to this instance.
 */
@Service
public class RealtimeService implements MessageListener {

    static final String CHANNEL = "realtime";

    private static final Logger log = LoggerFactory.getLogger(RealtimeService.class);

    private final StringRedisTemplate redis;
    private final SimpMessagingTemplate messaging;
    private final ObjectMapper objectMapper;

    public RealtimeService(StringRedisTemplate redis,
                           SimpMessagingTemplate messaging,
                           ObjectMapper objectMapper) {
        this.redis = redis;
        this.messaging = messaging;
        this.objectMapper = objectMapper;
    }

    public void publishDirectMessage(UUID recipientId, Object payload) {
        publish(RealtimeMessage.KIND_DM, recipientId.toString(), payload);
    }

    public void publishCommunityMessage(UUID communityId, Object payload) {
        publish(RealtimeMessage.KIND_COMMUNITY, communityId.toString(), payload);
    }

    private void publish(String kind, String target, Object payload) {
        try {
            RealtimeMessage envelope = new RealtimeMessage(kind, target,
                    objectMapper.valueToTree(payload));
            redis.convertAndSend(CHANNEL, objectMapper.writeValueAsString(envelope));
        } catch (Exception ex) {
            // Realtime is best-effort; the REST write already succeeded.
            log.warn("Failed to publish realtime event kind={} target={}", kind, target, ex);
        }
    }

    @Override
    public void onMessage(Message message, byte[] pattern) {
        try {
            RealtimeMessage envelope = objectMapper.readValue(
                    new String(message.getBody(), StandardCharsets.UTF_8), RealtimeMessage.class);
            switch (envelope.kind()) {
                case RealtimeMessage.KIND_DM -> messaging.convertAndSendToUser(
                        envelope.target(), "/queue/messages", envelope.payload());
                case RealtimeMessage.KIND_COMMUNITY -> messaging.convertAndSend(
                        "/topic/community." + envelope.target(), envelope.payload());
                default -> log.warn("Unknown realtime kind {}", envelope.kind());
            }
        } catch (Exception ex) {
            log.warn("Failed to dispatch realtime event", ex);
        }
    }
}
