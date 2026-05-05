package com.agriculture.common.exception;

public class InvalidOperationException extends BusinessException {

    public InvalidOperationException(String message) {
        super(400, message);
    }
}
