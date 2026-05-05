package com.agriculture.service;

import com.agriculture.model.dto.MoisturePredictionDTO;

public interface MoisturePredictor {

    MoisturePredictionDTO predict(Long pointId, int hoursAhead);

    MoisturePredictionDTO analyze(Long pointId, double threshold);

    double predictValue(Long pointId, int hoursAhead);
}
