package com.agriculture.service;

import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 多目标优化服务
 * 使用遗传算法（NSGA-II）优化灌溉决策
 * 
 * 优化目标：
 * 1. 湿度达标率最大化
 * 2. 用水量最小化
 * 3. 灌溉成本最小化（考虑峰谷电价）
 * 4. 作物健康最大化（避免湿度波动）
 */
@Slf4j
@Service
public class MultiObjectiveOptimizer {

    // 遗传算法参数
    private static final int POPULATION_SIZE = 50;
    private static final int MAX_GENERATIONS = 100;
    private static final double MUTATION_RATE = 0.1;
    private static final double CROSSOVER_RATE = 0.8;

    // 约束参数
    private static final double MIN_WATER = 1.0;
    private static final double MAX_WATER = 50.0;
    private static final int MIN_DURATION = 10;
    private static final int MAX_DURATION = 180;

    // 峰谷电价时段（简化模型）
    private static final int[] PEAK_HOURS = {9, 10, 11, 14, 15, 16, 17, 18, 19}; // 高峰时段
    private static final double PEAK_PRICE = 1.2;
    private static final double NORMAL_PRICE = 1.0;
    private static final double VALLEY_PRICE = 0.6;

    /**
     * 优化灌溉方案
     * 
     * @param currentMoisture 当前土壤湿度
     * @param targetMoisture 目标湿度
     * @param temperature 当前温度
     * @param currentHour 当前小时（用于电价计算）
     * @param cropFactor 作物灌溉系数
     * @return 优化后的灌溉方案
     */
    public OptimizationResult optimize(double currentMoisture, double targetMoisture,
                                        double temperature, int currentHour, double cropFactor) {
        
        log.info("开始多目标优化: currentMoisture={}, targetMoisture={}, temp={}, hour={}",
                currentMoisture, targetMoisture, temperature, currentHour);

        // 1. 初始化种群
        List<Individual> population = initializePopulation();

        // 2. 进化迭代
        for (int gen = 0; gen < MAX_GENERATIONS; gen++) {
            // 评估适应度
            for (Individual ind : population) {
                evaluateFitness(ind, currentMoisture, targetMoisture, temperature, currentHour, cropFactor);
            }

            // 非支配排序
            List<List<Individual>> fronts = fastNonDominatedSort(population);

            // 计算拥挤度
            for (List<Individual> front : fronts) {
                calculateCrowdingDistance(front);
            }

            // 选择、交叉、变异
            List<Individual> offspring = createOffspring(population);

            // 合并父代和子代
            population.addAll(offspring);

            // 再次排序选择
            fronts = fastNonDominatedSort(population);
            population = selectNewPopulation(fronts, POPULATION_SIZE);
        }

        // 3. 从帕累托前沿选择最优解
        Individual best = selectBestSolution(population, currentMoisture, targetMoisture);

        // 4. 构建结果
        OptimizationResult result = new OptimizationResult();
        result.setWaterAmount(BigDecimal.valueOf(best.waterAmount).setScale(2, RoundingMode.HALF_UP));
        result.setDurationSeconds(best.duration);
        result.setEstimatedMoistureGain(BigDecimal.valueOf(best.estimatedMoistureGain).setScale(2, RoundingMode.HALF_UP));
        result.setPredictedMoisture(BigDecimal.valueOf(currentMoisture + best.estimatedMoistureGain).setScale(2, RoundingMode.HALF_UP));
        result.setCost(BigDecimal.valueOf(best.cost).setScale(2, RoundingMode.HALF_UP));
        result.setHealthScore(BigDecimal.valueOf(best.healthScore).setScale(2, RoundingMode.HALF_UP));
        result.setParetoRank(best.rank);

        // 计算综合得分
        double totalScore = calculateTotalScore(best);
        result.setTotalScore(BigDecimal.valueOf(totalScore).setScale(3, RoundingMode.HALF_UP));

        log.info("优化完成: waterAmount={}, duration={}, cost={}, healthScore={}",
                result.getWaterAmount(), result.getDurationSeconds(), 
                result.getCost(), result.getHealthScore());

        return result;
    }

    /**
     * 初始化种群
     */
    private List<Individual> initializePopulation() {
        List<Individual> population = new ArrayList<>();
        Random random = new Random();

        for (int i = 0; i < POPULATION_SIZE; i++) {
            Individual ind = new Individual();
            ind.waterAmount = MIN_WATER + random.nextDouble() * (MAX_WATER - MIN_WATER);
            ind.duration = MIN_DURATION + random.nextInt(MAX_DURATION - MIN_DURATION);
            population.add(ind);
        }

        return population;
    }

    /**
     * 评估个体适应度（多目标）
     */
    private void evaluateFitness(Individual ind, double currentMoisture, double targetMoisture,
                                  double temperature, int currentHour, double cropFactor) {
        
        // 目标1：湿度差距（越小越好，转为越大越好）
        // 估算湿度提升（简化模型：每升水提升约1.5%）
        double moistureGain = ind.waterAmount * 1.5 * cropFactor;
        double moistureGap = Math.abs((currentMoisture + moistureGain) - targetMoisture);
        ind.estimatedMoistureGain = moistureGain;
        ind.moistureScore = Math.max(0, 100 - moistureGap * 2);

        // 目标2：用水量（越少越好，转为得分）
        ind.waterScore = Math.max(0, 100 - ind.waterAmount * 2);

        // 目标3：灌溉成本（考虑峰谷电价）
        double priceRate = getPriceRate(currentHour);
        ind.cost = ind.waterAmount * 0.01 * priceRate; // 假设每升水成本0.01元*电价系数
        ind.costScore = Math.max(0, 100 - ind.cost * 20);

        // 目标4：作物健康（基于灌溉时机和量）
        // 最佳灌溉量是基于湿度差的合理范围
        double idealWater = (targetMoisture - currentMoisture) / 1.5 / cropFactor;
        idealWater = Math.max(MIN_WATER, Math.min(MAX_WATER, idealWater));
        double waterDeviation = Math.abs(ind.waterAmount - idealWater) / idealWater;
        ind.healthScore = Math.max(0, 100 - waterDeviation * 50);

        // 温度影响（高温时灌溉效果好但蒸发损失大）
        if (temperature > 30) {
            ind.healthScore *= 0.9; // 高温时健康分数略降
            ind.cost *= 1.1; // 需要更多水
        }
    }

    /**
     * 获取当前时段电价系数
     */
    private double getPriceRate(int hour) {
        if (Arrays.stream(PEAK_HOURS).anyMatch(h -> h == hour)) {
            return PEAK_PRICE;
        } else if (hour >= 23 || hour < 7) {
            return VALLEY_PRICE;
        }
        return NORMAL_PRICE;
    }

    /**
     * 快速非支配排序（NSGA-II核心）
     */
    private List<List<Individual>> fastNonDominatedSort(List<Individual> population) {
        List<List<Individual>> fronts = new ArrayList<>();
        fronts.add(new ArrayList<>());

        for (Individual p : population) {
            p.dominationCount = 0;
            p.dominatedSet = new ArrayList<>();

            for (Individual q : population) {
                if (dominates(p, q)) {
                    p.dominatedSet.add(q);
                } else if (dominates(q, p)) {
                    p.dominationCount++;
                }
            }

            if (p.dominationCount == 0) {
                p.rank = 0;
                fronts.get(0).add(p);
            }
        }

        int i = 0;
        while (!fronts.get(i).isEmpty()) {
            List<Individual> nextFront = new ArrayList<>();
            for (Individual p : fronts.get(i)) {
                for (Individual q : p.dominatedSet) {
                    q.dominationCount--;
                    if (q.dominationCount == 0) {
                        q.rank = i + 1;
                        nextFront.add(q);
                    }
                }
            }
            i++;
            fronts.add(nextFront);
        }

        return fronts;
    }

    /**
     * 判断个体p是否支配个体q
     */
    private boolean dominates(Individual p, Individual q) {
        // 支配条件：所有目标不差于q，且至少有一个目标优于q
        boolean atLeastOneBetter = false;

        if (p.moistureScore < q.moistureScore) return false;
        if (p.moistureScore > q.moistureScore) atLeastOneBetter = true;

        if (p.waterScore < q.waterScore) return false;
        if (p.waterScore > q.waterScore) atLeastOneBetter = true;

        if (p.costScore < q.costScore) return false;
        if (p.costScore > q.costScore) atLeastOneBetter = true;

        if (p.healthScore < q.healthScore) return false;
        if (p.healthScore > q.healthScore) atLeastOneBetter = true;

        return atLeastOneBetter;
    }

    /**
     * 计算拥挤度距离
     */
    private void calculateCrowdingDistance(List<Individual> front) {
        if (front.isEmpty()) return;

        int n = front.size();
        for (Individual ind : front) {
            ind.crowdingDistance = 0;
        }

        // 对每个目标计算拥挤度
        calculateDistanceForObjective(front, Individual::getMoistureScore);
        calculateDistanceForObjective(front, Individual::getWaterScore);
        calculateDistanceForObjective(front, Individual::getCostScore);
        calculateDistanceForObjective(front, Individual::getHealthScore);
    }

    private void calculateDistanceForObjective(List<Individual> front, 
                                                java.util.function.Function<Individual, Double> getter) {
        front.sort(Comparator.comparingDouble(getter::apply));
        front.get(0).crowdingDistance = Double.POSITIVE_INFINITY;
        front.get(front.size() - 1).crowdingDistance = Double.POSITIVE_INFINITY;

        double minVal = getter.apply(front.get(0));
        double maxVal = getter.apply(front.get(front.size() - 1));
        double range = maxVal - minVal;

        if (range == 0) return;

        for (int i = 1; i < front.size() - 1; i++) {
            double distance = (getter.apply(front.get(i + 1)) - getter.apply(front.get(i - 1))) / range;
            front.get(i).crowdingDistance += distance;
        }
    }

    /**
     * 创建子代（选择、交叉、变异）
     */
    private List<Individual> createOffspring(List<Individual> population) {
        List<Individual> offspring = new ArrayList<>();
        Random random = new Random();

        while (offspring.size() < POPULATION_SIZE) {
            // 锦标赛选择
            Individual parent1 = tournamentSelection(population);
            Individual parent2 = tournamentSelection(population);

            // 交叉
            if (random.nextDouble() < CROSSOVER_RATE) {
                Individual child = crossover(parent1, parent2);
                offspring.add(child);
            } else {
                offspring.add(new Individual(parent1));
            }
        }

        // 变异
        for (Individual ind : offspring) {
            if (random.nextDouble() < MUTATION_RATE) {
                mutate(ind);
            }
        }

        return offspring;
    }

    /**
     * 锦标赛选择
     */
    private Individual tournamentSelection(List<Individual> population) {
        Random random = new Random();
        int tournamentSize = 3;
        Individual best = null;

        for (int i = 0; i < tournamentSize; i++) {
            Individual candidate = population.get(random.nextInt(population.size()));
            if (best == null || compareIndividuals(candidate, best) > 0) {
                best = candidate;
            }
        }

        return best;
    }

    /**
     * 比较两个个体（用于选择）
     */
    private int compareIndividuals(Individual a, Individual b) {
        // 先比较帕累托等级
        if (a.rank != b.rank) {
            return Integer.compare(a.rank, b.rank);
        }
        // 再比较拥挤度
        return Double.compare(a.crowdingDistance, b.crowdingDistance);
    }

    /**
     * 交叉操作
     */
    private Individual crossover(Individual p1, Individual p2) {
        Random random = new Random();
        Individual child = new Individual();

        // 模拟二进制交叉
        double beta = 2 * random.nextDouble() - 1;
        child.waterAmount = 0.5 * ((1 + beta) * p1.waterAmount + (1 - beta) * p2.waterAmount);
        child.duration = (int) (0.5 * (p1.duration + p2.duration));

        // 边界约束
        child.waterAmount = Math.max(MIN_WATER, Math.min(MAX_WATER, child.waterAmount));
        child.duration = Math.max(MIN_DURATION, Math.min(MAX_DURATION, child.duration));

        return child;
    }

    /**
     * 变异操作
     */
    private void mutate(Individual ind) {
        Random random = new Random();

        // 多项式变异
        double delta = 0.5 * (2 * random.nextDouble() - 1);
        ind.waterAmount += delta * 5;
        ind.waterAmount = Math.max(MIN_WATER, Math.min(MAX_WATER, ind.waterAmount));

        if (random.nextDouble() < 0.5) {
            ind.duration += random.nextInt(20) - 10;
            ind.duration = Math.max(MIN_DURATION, Math.min(MAX_DURATION, ind.duration));
        }
    }

    /**
     * 选择新一代种群
     */
    private List<Individual> selectNewPopulation(List<List<Individual>> fronts, int size) {
        List<Individual> newPopulation = new ArrayList<>();

        for (List<Individual> front : fronts) {
            if (newPopulation.size() + front.size() <= size) {
                newPopulation.addAll(front);
            } else {
                // 按拥挤度排序
                front.sort((a, b) -> Double.compare(b.crowdingDistance, a.crowdingDistance));
                int remaining = size - newPopulation.size();
                newPopulation.addAll(front.subList(0, remaining));
                break;
            }
        }

        return newPopulation;
    }

    /**
     * 从帕累托前沿选择最优解
     */
    private Individual selectBestSolution(List<Individual> population, 
                                           double currentMoisture, double targetMoisture) {
        // 找到帕累托前沿（rank=0的个体）
        List<Individual> paretoFront = population.stream()
                .filter(ind -> ind.rank == 0)
                .collect(Collectors.toList());

        if (paretoFront.isEmpty()) {
            paretoFront = population;
        }

        // 根据综合得分选择
        return paretoFront.stream()
                .max(Comparator.comparingDouble(this::calculateTotalScore))
                .orElse(paretoFront.get(0));
    }

    /**
     * 计算综合得分
     */
    private double calculateTotalScore(Individual ind) {
        // 加权综合（可根据实际需求调整权重）
        double w1 = 0.35; // 湿度达标权重
        double w2 = 0.25; // 节水权重
        double w3 = 0.20; // 成本权重
        double w4 = 0.20; // 健康权重

        return w1 * ind.moistureScore + w2 * ind.waterScore + 
               w3 * ind.costScore + w4 * ind.healthScore;
    }

    /**
     * 个体类（染色体）
     */
    @Data
    private static class Individual {
        // 决策变量
        double waterAmount;
        int duration;

        // 目标函数值
        double moistureScore;
        double waterScore;
        double costScore;
        double healthScore;

        // 辅助变量
        double estimatedMoistureGain;
        double cost;
        int rank;
        double crowdingDistance;
        int dominationCount;
        List<Individual> dominatedSet;

        public Individual() {}

        public Individual(Individual other) {
            this.waterAmount = other.waterAmount;
            this.duration = other.duration;
            this.moistureScore = other.moistureScore;
            this.waterScore = other.waterScore;
            this.costScore = other.costScore;
            this.healthScore = other.healthScore;
            this.estimatedMoistureGain = other.estimatedMoistureGain;
            this.cost = other.cost;
        }

        public double getMoistureScore() { return moistureScore; }
        public double getWaterScore() { return waterScore; }
        public double getCostScore() { return costScore; }
        public double getHealthScore() { return healthScore; }
    }

    /**
     * 优化结果
     */
    @Data
    public static class OptimizationResult {
        private BigDecimal waterAmount;        // 推荐用水量(L)
        private int durationSeconds;           // 灌溉时长(秒)
        private BigDecimal estimatedMoistureGain; // 预计湿度提升
        private BigDecimal predictedMoisture;  // 预测灌溉后湿度
        private BigDecimal cost;               // 预估成本
        private BigDecimal healthScore;        // 作物健康得分
        private BigDecimal totalScore;         // 综合得分
        private int paretoRank;                // 帕累托等级
        
        // 各目标得分明细
        private Map<String, Double> objectiveScores;
    }

    /**
     * 获取优化算法的详细信息（用于展示）
     */
    public Map<String, Object> getAlgorithmInfo() {
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("name", "NSGA-II 多目标遗传算法");
        info.put("description", "在节水、成本、作物健康间寻找帕累托最优解");
        
        Map<String, Object> objectives = new LinkedHashMap<>();
        objectives.put("moistureScore", "湿度达标率（目标：最大化）");
        objectives.put("waterScore", "节水量（目标：最大化）");
        objectives.put("costScore", "经济成本（目标：最小化）");
        objectives.put("healthScore", "作物健康（目标：最大化）");
        info.put("objectives", objectives);

        Map<String, Object> params = new LinkedHashMap<>();
        params.put("populationSize", POPULATION_SIZE);
        params.put("maxGenerations", MAX_GENERATIONS);
        params.put("mutationRate", MUTATION_RATE);
        params.put("crossoverRate", CROSSOVER_RATE);
        info.put("parameters", params);

        return info;
    }
}
