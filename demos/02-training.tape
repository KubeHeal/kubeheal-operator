# KubeHeal Operator -- Model Training Pipeline
# Records: Tekton pipeline start, log streaming, InferenceService readiness, inference test
# Duration: ~5 minutes
# Requires: KubeHeal platform deployed with RHOAI and Tekton operators

Output demos/02-training.gif

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Dracula"
Set TypingSpeed 40ms
Set Padding 20

# --- Title ---
Type "# KubeHeal -- Anomaly Detection Model Training"
Enter
Sleep 1s

# --- Step 1: Verify prerequisites ---
Type "oc get pipeline -n self-healing-platform"
Enter
Sleep 3s

Type "oc get inferenceservice -n self-healing-platform"
Enter
Sleep 3s

# --- Step 2: Start model training pipeline ---
Type "tkn pipeline start model-training-pipeline \"
Enter
Type "  -p model-name=anomaly-detector \"
Enter
Type "  -p notebook-path=notebooks/02-anomaly-detection/01-isolation-forest-implementation.ipynb \"
Enter
Type "  -p data-source=prometheus \"
Enter
Type "  -p training-hours=168 \"
Enter
Type "  -p inference-service-name=anomaly-detector \"
Enter
Type "  -p health-check-enabled=true \"
Enter
Type "  -p git-url=https://github.com/KubeHeal/openshift-aiops-platform.git \"
Enter
Type "  -p git-ref=main \"
Enter
Type "  -n self-healing-platform --showlog"
Enter
Sleep 5s

# --- Step 3: Show pipeline progressing (simulated wait) ---
Type "# Pipeline is running... (takes 5-10 minutes for full training)"
Enter
Sleep 2s

Type "tkn pipelinerun list -n self-healing-platform"
Enter
Sleep 3s

# --- Step 4: Check model readiness ---
Type "echo 'Waiting for model to become ready...' && sleep 30"
Enter
Sleep 31s

Type "oc get inferenceservice anomaly-detector -n self-healing-platform"
Enter
Sleep 3s

# --- Step 5: Test inference endpoint ---
Type "ROUTE=$(oc get route anomaly-detector -n self-healing-platform -o jsonpath='{.spec.host}' 2>/dev/null)"
Enter
Sleep 1s

Type "echo \"Inference endpoint: https://${ROUTE}\""
Enter
Sleep 2s

Type "curl -sk https://${ROUTE}/v1/models/anomaly-detector:predict \\"
Enter
Type "  -H 'Content-Type: application/json' \\"
Enter
Type "  -d '{\"instances\": [[0.5, 0.8, 0.3, 0.9, 0.1]]}' | jq ."
Enter
Sleep 5s

# --- Step 6: Run deployment validation ---
Type "tkn pipeline start deployment-validation-pipeline -n self-healing-platform --showlog"
Enter
Sleep 5s

Type "echo '✅ Model trained, deployed, and serving predictions!'"
Enter
Sleep 3s
