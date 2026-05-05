package com.agriculture.common.exception;

public class DuplicateResourceException extends BusinessException {

    public DuplicateResourceException(String resource, Object identifier) {
        super(409, resource + "已存在: " + identifier);
    }

    public DuplicateResourceException(String message) {
        super(409, message);
    }
}
