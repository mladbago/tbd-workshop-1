import os
import sys
import polars as pl

EVENTS_PATH = sys.argv[1]
N_ROWS = int(sys.argv[2])
current_threads = os.environ.get("POLARS_MAX_THREADS")

import time
def run_benchmark_local(fn):
    import gc; gc.collect()

    start_time = time.perf_counter()
    res = fn()
    end_time = time.perf_counter()

    import psutil
    process = psutil.Process(os.getpid())
    peak_mem = process.memory_info().rss / 1e6 # MB

    return (end_time - start_time), peak_mem, res

# Define the target query graph
def scalability_query():
    return (
        pl.scan_parquet(EVENTS_PATH)
        .explode("tags")
        .group_by("tags")
        .len()
        .sort("len", descending=True)
        .head(10)
        .collect()
    )

t, m, r = run_benchmark_local(scalability_query)

print(f"RESULT_METRICS:{t}:{m}:{r.height}:{r['len'].sum()}")
