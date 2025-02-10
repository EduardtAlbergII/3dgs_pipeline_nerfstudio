#!/bin/bash

start_time=$(date +%s.%N)

echo Splatting Dataset $DATASET

step_times=()
measure_step() {
    end_time=$(date +%s.%N)
    step_duration=$(echo "$end_time - $start_time" | bc)
    step_times+=("$DATASET: $step_duration seconds")
    start_time=$end_time
}

measure_step "Directory creation"

if [ -f /workspace/data/$DATASET/*.* ]; then
    if [ -d /workspace/data/$DATASET/images ]; then
        echo "images foulder found, skip frame extraction"
    else
        if [ -f /workspace/data/$DATASET/*.zip ]; then
            echo "Processing nerf capture data"
            unzip /workspace/data/$DATASET/*.zip -d /workspace/data/$DATASET/
            rm /workspace/data/$DATASET/*.zip
            mv /workspace/data/$DATASET/* /workspace/data/$DATASET/ns-process/
            if [ -f /workspace/data/$DATASET/ns-process/transforms.json ]; then
                cp /workspace/data/$DATASET/ns-process/transforms.json /workspace/data/$DATASET/ns-process/transforms.json.backup
                sed -i 's/"file_path":"images\/\([0-9]*\)"/"file_path":"images\/\1.png"/g' /workspace/data/$DATASET/ns-process/transforms.json
            else
                echo "No transforms.json found, please zip the nerfcapture folder on your phone manually and upload it again"
                exit 1
            fi
        else
            echo "Extracting frames from video"
            mkdir -p /workspace/data/$DATASET/images
            ffmpeg -i /workspace/data/$DATASET/$DATASET.* -vf "scale='if(gt(a,1),$RESOLUTION,-2)':'if(gt(a,1),-2,$RESOLUTION)',fps=$VIDEO_TO_IMAGE_FPS" -qscale:v 2 -qmin 2 -qmax 2 /workspace/data/$DATASET/images/frame_%04d.jpg
            python3 /opt/nerf_dataset_preprocessing_helper/01_filter_raw_data.py --input_path /workspace/data/$DATASET/images --output_path /workspace/data/$DATASET/images --target_percentage 95 --groups 1 -y
            python3 /opt/nerf_dataset_preprocessing_helper/01_filter_raw_data.py --input_path /workspace/data/$DATASET/images --output_path /workspace/data/$DATASET/images --target_count 1200 --scalar 3 -y
            measure_step "Frame extraction"
        fi
    fi
fi

if [ -d /workspace/data/$DATASET/ns-process ]; then
    echo "ns-process foulder found, skip sfm (colmap)"
else
    if [ -d /workspace/data/$DATASET/colmap ]; then
        echo "colmap foulder found, skip matcher"
    else
        echo "colmap feature_extractor"
        mkdir -p /workspace/data/$DATASET/colmap
        colmap feature_extractor --image_path /workspace/data/$DATASET/images --database_path /workspace/data/$DATASET/colmap/database.db --SiftExtraction.use_gpu 1
        measure_step "Feature extraction"

        echo "colmap $MAPPER_TYPE"
        colmap $MAPPER_TYPE --database_path /workspace/data/$DATASET/colmap/database.db
        measure_step "matcher"
        
        if [ "$SFM" = "colmap" ]; then
            echo "colmap mapper"
            colmap mapper --database_path /workspace/data/$DATASET/colmap/database.db --image_path /workspace/data/$DATASET/images --output_path /workspace/data/$DATASET/colmap
            measure_step "Colmap mapping"
        fi
        
        if [ "$SFM" = "glomap" ]; then
            echo "glomap mapper"
            glomap mapper --database_path /workspace/data/$DATASET/colmap/database.db --image_path /workspace/data/$DATASET/images --output_path /workspace/data/$DATASET/colmap
            measure_step "Glomap mapping"
        fi
    fi
fi

echo "GSplat processing"

if [ -d /workspace/data/$DATASET/ns-process ]; then
    echo "ns-process foulder found, skip ns-process"
else
    echo "ns-process"
    ns-process-data images --data /workspace/data/$DATASET/images --output-dir /workspace/data/$DATASET/ns-process --skip-colmap --colmap-model-path /workspace/data/$DATASET/colmap/0
    measure_step "NS Process"
    python3 /opt/nerf_dataset_preprocessing_helper/02_filter_colmap_data.py --transforms_path /workspace/data/$DATASET/ns-process --target_count 450 -y
    mv /workspace/data/$DATASET/transforms_filtered.json /workspace/data/$DATASET/ns-process/transforms.json
    measure_step "Filtering colmap data"
fi

if [ -d /workspace/data/$DATASET/ns-train ]; then
    echo "ns-train foulder found, skip ns-train"
else
    echo "ns-train"
    mkdir -p /workspace/data/$DATASET/ns-train
    ns-train splatfacto --max-num-iterations $ITERATION_COUNT  --vis viewer+tensorboard --viewer.quit-on-train-completion=True --data /workspace/data/$DATASET/ns-process --output-dir /workspace/data/$DATASET/ns-train
    measure_step "Training complete"
fi

echo "ns-export"
ns-export gaussian-splat --load-config /workspace/data/$DATASET/ns-train/ns-process/splatfacto/202*/config.yml --output-dir /workspace/data/$DATASET/
measure_step "Exporting splat"
if [ -d /workspace/data/$DATASET/ns-train ]; then
    echo "Removing ns-train folder"
    rm -rf /workspace/data/$DATASET/ns-train
    measure_step "Tidying up temporary files"
fi


echo "Step execution times:"
printf '%s\n' "${step_times[@]}"