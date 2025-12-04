#!/bin/bash

# Log all output to a log file (stdout and stderr)
mkdir -p logs
start_time_formatted=$(date +%Y%m%d_%H%M%S)
log_file="logs/sbs-${start_time_formatted}.log"
exec > >(tee -a "$log_file") 2>&1

# Start timing
start_time=$(date +%s)

# Set number of plates to process
NUM_PLATES=1

echo "===== STARTING SEQUENTIAL PROCESSING OF $NUM_PLATES PLATES ====="

# Process each plate in sequence
for PLATE in $(seq 1 $NUM_PLATES); do
    echo ""
    echo "==================== PROCESSING PLATE $PLATE ===================="
    echo "Started at: $(date)"

    # Start timing for this plate
    plate_start_time=$(date +%s)

    # Run Snakemake with plate filter for this plate (local execution)
    # Group all tile-based rules together for maximum parallelization
    snakemake --use-conda \
        --snakefile "../brieflow/workflow/Snakefile" \
        --configfile "config/config.yml" \
        --rerun-triggers mtime \
        --rerun-incomplete \
        --keep-going \
        --cores 200 \
        --groups align_sbs=sbs_tile_group \
                log_filter=sbs_tile_group \
                compute_standard_deviation=sbs_tile_group \
                find_peaks=sbs_tile_group \
                max_filter=sbs_tile_group \
                apply_ic_field_sbs=sbs_tile_group \
                segment_sbs=sbs_tile_group \
                extract_bases=sbs_tile_group \
                call_reads=sbs_tile_group \
                call_cells=sbs_tile_group \
                extract_sbs_info=sbs_tile_group \
        --until all_sbs \
        --config plate_filter=$PLATE

    # Check if Snakemake was successful
    if [ $? -ne 0 ]; then
        echo "ERROR: Processing of plate $PLATE failed. Stopping sequential run."
        exit 1
    fi

    # End timing and calculate duration for this plate
    plate_end_time=$(date +%s)
    plate_duration=$((plate_end_time - plate_start_time))

    echo "==================== PLATE $PLATE COMPLETED ===================="
    echo "Finished at: $(date)"
    echo "Runtime for plate $PLATE: $((plate_duration / 3600))h $(((plate_duration % 3600) / 60))m $((plate_duration % 60))s"
    echo ""

    # Optional: Add a short pause between plates
    sleep 5
done

# End timing and calculate total duration
end_time=$(date +%s)
total_duration=$((end_time - start_time))

echo "===== ALL $NUM_PLATES PLATES PROCESSED SUCCESSFULLY ====="
echo "Total runtime: $((total_duration / 3600))h $(((total_duration % 3600) / 60))m $((total_duration % 60))s"
echo "Log file: $log_file"
