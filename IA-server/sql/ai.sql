CREATE TABLE chat_history (
                              id BIGINT PRIMARY KEY AUTO_INCREMENT,
                              session_id VARCHAR(100) NOT NULL COMMENT '会话ID',
                              role VARCHAR(20) NOT NULL COMMENT '角色: user/assistant',
                              content TEXT NOT NULL COMMENT '消息内容',
                              token_count INT COMMENT 'Token数量',
                              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                              INDEX idx_session_created (session_id, created_at)
);