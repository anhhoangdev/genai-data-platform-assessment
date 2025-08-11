#!/usr/bin/env python
"""
Example Dask job that runs on Dataproc using dask-yarn

This script demonstrates:
- Creating a YarnCluster on Dataproc
- Using Dask for distributed data processing
- Reading from and writing to GCS
- Optional: Reading from NFS mount
"""

import argparse
import logging
import sys
from pathlib import Path

import dask.dataframe as dd
from dask_yarn import YarnCluster
from dask.distributed import Client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(description='Dask on YARN example job')
    parser.add_argument('--input', required=True, help='Input data path (GCS or NFS)')
    parser.add_argument('--output', required=True, help='Output data path (GCS or NFS)')
    parser.add_argument('--worker-memory', default='4GiB', help='Memory per worker')
    parser.add_argument('--worker-vcores', default=2, type=int, help='vCores per worker')
    parser.add_argument('--n-workers', default=4, type=int, help='Number of workers')
    
    args = parser.parse_args()
    
    logger.info("Starting Dask job on Dataproc")
    logger.info(f"Input: {args.input}")
    logger.info(f"Output: {args.output}")
    
    # Create YarnCluster
    logger.info("Creating YarnCluster...")
    cluster = YarnCluster(
        environment='/opt/conda/default',  # Conda environment installed by init action
        worker_memory=args.worker_memory,
        worker_vcores=args.worker_vcores,
        n_workers=args.n_workers
    )
    
    # Create Dask client
    client = Client(cluster)
    logger.info(f"Dask dashboard available at: {client.dashboard_link}")
    logger.info(f"Cluster has {len(client.scheduler_info()['workers'])} workers")
    
    try:
        # Example: Read CSV data
        logger.info("Reading input data...")
        df = dd.read_csv(args.input)
        
        # Example transformations
        logger.info("Performing data transformations...")
        
        # 1. Basic statistics
        stats = df.describe().compute()
        logger.info(f"Data statistics:\n{stats}")
        
        # 2. Example transformation: normalize numeric columns
        numeric_cols = df.select_dtypes(include=['float64', 'int64']).columns
        for col in numeric_cols:
            df[f'{col}_normalized'] = (df[col] - df[col].mean()) / df[col].std()
        
        # 3. Example aggregation
        if 'category' in df.columns:
            category_counts = df['category'].value_counts().compute()
            logger.info(f"Category counts:\n{category_counts}")
        
        # 4. Save results
        logger.info(f"Saving results to {args.output}...")
        
        # For GCS output, ensure we have proper credentials
        if args.output.startswith('gs://'):
            # GCS output - Dask handles this automatically with gcsfs
            df.to_csv(args.output, index=False)
        elif args.output.startswith('/mnt/shared/'):
            # NFS output - ensure directory exists
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            df.to_csv(args.output, index=False)
        else:
            # Local output (for testing)
            df.to_csv(args.output, index=False)
        
        logger.info("Job completed successfully!")
        
    except Exception as e:
        logger.error(f"Job failed with error: {e}", exc_info=True)
        raise
    
    finally:
        # Clean up
        logger.info("Shutting down Dask cluster...")
        client.close()
        cluster.close()


if __name__ == '__main__':
    main()
