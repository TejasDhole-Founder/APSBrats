package com.apsconnect.api.media;

import com.apsconnect.api.common.exception.AppException;
import com.apsconnect.api.common.exception.ErrorCode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.net.URI;

/**
 * Cloudflare R2 (S3-compatible object storage) behind the same {@link StorageService}
 * contract as {@link LocalStorageService} — callers never know which one is active.
 * Enable with {@code app.storage.type=r2}. The bucket must already have a public base
 * URL (custom domain, e.g. media.apsbrats.com): that URL is {@code app.media.base-url},
 * the same property {@link ImageUploadService#requireOwnUpload} checks ownership against,
 * so the two can never drift apart.
 */
@Service
@ConditionalOnProperty(name = "app.storage.type", havingValue = "r2")
public class R2StorageService implements StorageService {

    private final S3Client client;
    private final String bucket;
    private final String publicBaseUrl;

    public R2StorageService(
            @Value("${app.storage.r2.account-id}") String accountId,
            @Value("${app.storage.r2.access-key}") String accessKey,
            @Value("${app.storage.r2.secret-key}") String secretKey,
            @Value("${app.storage.r2.bucket}") String bucket,
            @Value("${app.media.base-url}") String publicBaseUrl) {
        this.bucket = bucket;
        this.publicBaseUrl = publicBaseUrl.endsWith("/")
                ? publicBaseUrl.substring(0, publicBaseUrl.length() - 1) : publicBaseUrl;
        // R2's S3-compatible endpoint is per-account, not a fixed AWS region.
        this.client = S3Client.builder()
                .endpointOverride(URI.create("https://" + accountId + ".r2.cloudflarestorage.com"))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey, secretKey)))
                // R2 ignores the region, but the SDK requires a well-formed one.
                .region(Region.of("auto"))
                .build();
    }

    @Override
    public String store(String key, byte[] content, String contentType) {
        try {
            client.putObject(
                    PutObjectRequest.builder().bucket(bucket).key(key).contentType(contentType).build(),
                    RequestBody.fromBytes(content));
            return publicBaseUrl + "/" + key;
        } catch (SdkException ex) {
            throw new AppException("Could not store file", HttpStatus.INTERNAL_SERVER_ERROR, ErrorCode.INTERNAL_ERROR);
        }
    }
}
