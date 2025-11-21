
library(ggplot2)
library(locationallocation)
library(sf)
library(pbapply)

set.seed(333)

candidates <- st_sample(naples_shape, 20)

# Define a set of parameter combinations
params <- expand.grid(
  res_output = c(100, 500, 1000),
  n_fac = c(3, 8, 15),
  n_samples = c(100, 1000, 1e4)
)

# Function to run benchmarks
run_benchmark <- function(i) {
  # Generate travel time map
  tt_result_time <- system.time(tt_result <- traveltime(
    facilities = naples_fountains,
    bb_area = naples_shape,
    dowscaling_model_type = "lm",
    mode = "walk",
    res_output = params$res_output[i]
  ))


  # Optimize allocation
  alloc_result_time <- system.time(alloc_result <- allocation(
    demand = naples_population,
    bb_area = naples_shape,
    facilities = naples_fountains,
    objectiveminutes = 15,
    objectiveshare = 0.99,
    heur = "max",
    dowscaling_model_type = "lm",
    res_output = params$res_output[i]
  ))

  set.seed(333)

  # Optimize allocation discrete
  alloc_result_discrete_time <- system.time(alloc_result_discrete <- allocation_discrete(demand = naples_population, bb_area = naples_shape, facilities=naples_fountains, candidate=candidates, n_fac = params$n_fac[i], weights=NULL, objectiveminutes=15, dowscaling_model_type="lm", mode="walk", res_output=params$res_output[i], n_samples=params$n_samples[i], par=F))

  # Return execution times
  list(
    tt_result_time = tt_result_time,
    alloc_result_time = alloc_result_time,
    alloc_result_discrete_time = alloc_result_discrete_time
  )
}

# Run benchmarks for all parameter combinations
benchmark_results <- pblapply(1:nrow(params), run_benchmark)

#################
################

# Convert results to a data frame
benchmark_df <- do.call(rbind, benchmark_results)
benchmark_df$res_output <- rep(params$res_output, each = nrow(benchmark_results) / length(params$res_output))
benchmark_df$n_fac <- rep(params$n_fac, each = nrow(benchmark_results) / length(params$n_fac))
benchmark_df$n_samples <- rep(params$n_samples, each = nrow(benchmark_results) / length(params$n_samples))

###

# Plot results
ggplot(benchmark_df, aes(x = interaction(mode, res_output), y = tt_time)) +
  geom_boxplot() +
  labs(title = "Travel Time Calculation Time by Mode and Resolution",
       x = "Mode and Resolution",
       y = "Time (seconds)") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Save plot
ggsave("benchmark_plot.png")

# Summarize results
summary_stats <- aggregate(cbind(tt_time, tt_stats_time, alloc_time) ~ mode + res_output + objectiveminutes + weights, data = benchmark_df, FUN = mean)
write.csv(summary_stats, "benchmark_summary.csv")
