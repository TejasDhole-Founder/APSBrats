package com.apsconnect.api.chat;

import com.apsconnect.api.auth.AuthService;
import com.apsconnect.api.auth.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.stereotype.Component;
import org.springframework.messaging.support.MessageHeaderAccessor;
import java.security.Principal;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class StompAuthChannelInterceptor implements ChannelInterceptor {

    private final JwtService jwtService;
    private final AuthService authService;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

        if (StompCommand.CONNECT.equals(accessor.getCommand())) {
            String header = accessor.getFirstNativeHeader("Authorization");
            if (header == null || !header.startsWith("Bearer ")) {
                throw new IllegalArgumentException("Missing Authorization header");
            }
            var claims = jwtService.parseAccess(header.substring(7));
            if (authService.isRevoked(claims.userId(), claims.issuedAt())) {
                throw new IllegalArgumentException("Session ended");
            }
            String userIdString = claims.userId().toString();
            accessor.setUser((Principal) () -> userIdString);
        }

        // Messages are sent over REST; a client SEND would publish straight to the broker.
        if (StompCommand.SEND.equals(accessor.getCommand())) {
            throw new IllegalArgumentException("Sending over the socket is not supported");
        }

        if (StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
            String destination = accessor.getDestination();
            if (destination == null || !destination.startsWith("/user/queue/")) {
                throw new IllegalArgumentException("Invalid subscription destination");
            }
        }

        return message;
    }
}