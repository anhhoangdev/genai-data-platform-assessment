#!/usr/bin/env python
"""
Large-scale Dask processing job with adaptive scaling

This script demonstrates:
- Processing large Parquet datasets
- Adaptive cluster scaling with dask-yarn
- Complex distributed computations
- Integration with both GCS and NFS storage
"""

import argparse
import logging
import time
from datetime import datetime
from typing import Optional

import dask
import dask.dataframe as dd
import numpy as np
from dask_yarn import YarnCluster
from dask.distributed import Client, as_completed

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Dask configuration for better performance
dask.config.set({
    'dataframe.shuffle.method': 'tasks',
    'distributed.scheduler.allowed-failures': 10,
    'distributed.scheduler.work-stealing': True
})


class LargeScaleProcessor:
    """Handles large-scale data processing with Dask"""
    
    def __init__(self, client: Client):
        self.client = client
        self.start_time = time.time()
    
    def process_dataset(self, df: dd.DataFrame) -> dd.DataFrame:
        """Apply complex transformations to the dataset"""
        logger.info("Starting dataset processing...")
        
        # 1. Data quality checks
        initial_rows = df.map_partitions(len).sum().compute()
        logger.info(f"Processing {initial_rows:,} rows")
        
        # 2. Feature engineering
        logger.info("Performing feature engineering...")
        
        # Add time-based features if timestamp column exists
        if 'timestamp' in df.columns:
            df['timestamp'] = dd.to_datetime(df['timestamp'])
            df['hour'] = df['timestamp'].dt.hour
            df['day_of_week'] = df['timestamp'].dt.dayofweek
            df['month'] = df['timestamp'].dt.month
            
        # 3. Complex aggregations
        logger.info("Computing aggregations...")
        
        # Example: Rolling statistics if we have time series data
        if 'timestamp' in df.columns and 'value' in df.columns:
            df = df.set_index('timestamp')
            df['rolling_mean'] = df['value'].rolling('7D').mean()
            df['rolling_std'] = df['value'].rolling('7D').std()
            df = df.reset_index()
        
        # 4. Advanced transformations
        numeric_columns = df.select_dtypes(include=[np.number]).columns
        
        for col in numeric_columns:
            # Outlier detection using IQR
            q1 = df[col].quantile(0.25)
            q3 = df[col].quantile(0.75)
            iqr = q3 - q1
            
            df[f'{col}_is_outlier'] = (
                (df[col] < (q1 - 1.5 * iqr)) | 
                (df[col] > (q3 + 1.5 * iqr))
            )
            
            # Log transformation for positive values
            df[f'{col}_log'] = df[col].where(df[col] > 0).apply(
                np.log1p, meta=('x', 'f8')
            )
        
        # 5. Data enrichment
        logger.info("Enriching dataset...")
        
        # Example: Add statistical features
        for col in numeric_columns[:5]:  # Limit to first 5 to avoid explosion
            df[f'{col}_zscore'] = (df[col] - df[col].mean()) / df[col].std()
            
        final_rows = df.map_partitions(len).sum().compute()
        logger.info(f"Processed dataset has {final_rows:,} rows")
        
        return df
    
    def save_results(self, df: dd.DataFrame, output_path: str):
        """Save processed data with partitioning"""
        logger.info(f"Saving results to {output_path}")
        
        # Repartition for optimal file sizes (aim for ~100-200MB per file)
        n_partitions = max(1, df.map_partitions(
            lambda x: x.memory_usage(deep=True).sum()
        ).sum().compute() // (100 * 1024 * 1024))
        
        df = df.repartition(npartitions=n_partitions)
        
        # Save as Parquet with compression
        df.to_parquet(
            output_path,
            engine='pyarrow',
            compression='snappy',
            write_index=False
        )
        
        elapsed = time.time() - self.start_time
        logger.info(f"Processing completed in {elapsed:.2f} seconds")


def main():
    parser = argparse.ArgumentParser(description='Large-scale Dask processing')
    parser.add_argument('--input-pattern', required=True, 
                        help='Input data pattern (e.g., gs://bucket/data/*.parquet)')
    parser.add_argument('--output-path', required=True,
                        help='Output path for processed data')
    parser.add_argument('--min-workers', default=2, type=int,
                        help='Minimum number of workers')
    parser.add_argument('--max-workers', default=10, type=int,
                        help='Maximum number of workers')
    parser.add_argument('--adaptive-scaling', default='true',
                        help='Enable adaptive scaling')
    parser.add_argument('--worker-memory', default='8GiB',
                        help='Memory per worker')
    parser.add_argument('--worker-vcores', default=4, type=int,
                        help='vCores per worker')
    
    args = parser.parse_args()
    
    logger.info("Starting large-scale Dask processing job")
    logger.info(f"Configuration: {vars(args)}")
    
    # Create YarnCluster with more resources
    logger.info("Creating YarnCluster...")
    cluster = YarnCluster(
        environment='/opt/conda/default',
        worker_memory=args.worker_memory,
        worker_vcores=args.worker_vcores,
        name='large-scale-processor'
    )
    
    # Configure adaptive scaling
    if args.adaptive_scaling.lower() == 'true':
        logger.info(f"Enabling adaptive scaling: {args.min_workers} to {args.max_workers} workers")
        cluster.adapt(
            minimum=args.min_workers,
            maximum=args.max_workers,
            wait_count=3,  # Wait for 3 cycles before scaling
            interval='10s'  # Check every 10 seconds
        )
    else:
        # Fixed scaling
        cluster.scale(args.min_workers)
    
    # Create client
    client = Client(cluster)
    logger.info(f"Dask dashboard: {client.dashboard_link}")
    
    try:
        # Initialize processor
        processor = LargeScaleProcessor(client)
        
        # Read data
        logger.info(f"Reading data from {args.input_pattern}")
        df = dd.read_parquet(args.input_pattern, engine='pyarrow')
        
        # Show initial cluster state
        logger.info(f"Initial cluster state: {len(client.scheduler_info()['workers'])} workers")
        
        # Process data
        processed_df = processor.process_dataset(df)
        
        # Monitor cluster during processing
        def monitor_cluster():
            while True:
                info = client.scheduler_info()
                n_workers = len(info['workers'])
                n_tasks = sum(len(w['processing']) for w in info['workers'].values())
                logger.info(f"Cluster status: {n_workers} workers, {n_tasks} active tasks")
                time.sleep(30)
        
        # Start monitoring in background
        monitor_future = client.submit(monitor_cluster, pure=False)
        
        # Save results
        processor.save_results(processed_df, args.output_path)
        
        # Cancel monitoring
        monitor_future.cancel()
        
        logger.info("Job completed successfully!")
        
        # Print final statistics
        final_info = client.scheduler_info()
        logger.info(f"Final cluster state: {len(final_info['workers'])} workers")
        logger.info(f"Total tasks executed: {sum(w['metrics']['tasks'] for w in final_info['workers'].values())}")
        
    except Exception as e:
        logger.error(f"Job failed: {e}", exc_info=True)
        raise
        
    finally:
        logger.info("Cleaning up...")
        client.close()
        cluster.close()


if __name__ == '__main__':
    main()
