package com.agriculture.common.exception;

import lombok.Getter;

@Getter
public class BusinessException extends RuntimeException {

    private final int errorCode;

    public BusinessException(String message) {
        super(message);
        this.errorCode = 500;
    }

    public BusinessException(int errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public BusinessException(int errorCode, String message, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
    }
}
