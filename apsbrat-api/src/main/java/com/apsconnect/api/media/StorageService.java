package com.apsconnect.api.media;

public interface StorageService {
    /**
     * Persists bytes under the given key and returns a servable URL/path.
     * Implementations back this with local disk (dev) or object storage (prod).
     */
    String store(String key, byte[] content, String contentType);
}
