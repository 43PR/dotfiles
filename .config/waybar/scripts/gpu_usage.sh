#!/bin/bash

nvtop -s | jq -r '.[0].gpu_util' | tr -d '%'
