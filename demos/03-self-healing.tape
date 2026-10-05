# KubeHeal Operator -- Self-Healing in Action
# Records: Fault injection, coordination engine detection, automated remediation
# Duration: ~5 minutes
# Requires: KubeHeal platform fully deployed with coordination engine running

Output demos/03-self-healing.gif

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Dracula"
Set TypingSpeed 40ms
Set Padding 20

# --- Title ---
Type "# KubeHeal -- Self-Healing Demo: Fault Injection + Recovery"
Enter
Sleep 1s

# --- Step 1: Show current healthy state ---
Type "oc get pods -n self-healing-platform"
Enter
Sleep 3s

Type "oc get pods -n self-healing-platform -l app.kubernetes.io/component=coordination-engine"
Enter
Sleep 2s

# --- Step 2: Check coordination engine health ---
Type "oc exec -n self-healing-platform deployment/self-healing-coordination-engine -- curl -s http://localhost:8080/health | jq ."
Enter
Sleep 3s

# --- Step 3: Inject a fault -- kill the coordination engine pod ---
Type "echo '💥 Injecting fault: deleting coordination engine pod...'"
Enter
Sleep 1s

Type "CE_POD=$(oc get pod -n self-healing-platform -l app.kubernetes.io/component=coordination-engine -o jsonpath='{.items[0].metadata.name}')"
Enter
Sleep 1s

Type "oc delete pod ${CE_POD} -n self-healing-platform"
Enter
Sleep 3s

# --- Step 4: Watch Kubernetes self-heal the pod ---
Type "echo 'Watching pod recovery...'"
Enter
Sleep 1s

Type "oc get pods -n self-healing-platform -l app.kubernetes.io/component=coordination-engine -w &"
Enter
Sleep 10s

# --- Step 5: Kill the watch and show final state ---
Type "kill %1 2>/dev/null"
Enter
Sleep 1s

Type "oc get pods -n self-healing-platform -l app.kubernetes.io/component=coordination-engine"
Enter
Sleep 3s

# --- Step 6: Inject a second fault -- scale down a model ---
Type "echo '💥 Injecting fault: scaling down anomaly-detector predictor...'"
Enter
Sleep 1s

Type "oc scale deployment -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector --replicas=0"
Enter
Sleep 3s

# --- Step 7: Show the platform detecting the issue ---
Type "oc get inferenceservice anomaly-detector -n self-healing-platform"
Enter
Sleep 3s

Type "oc get events -n self-healing-platform --sort-by='.lastTimestamp' | tail -5"
Enter
Sleep 3s

# --- Step 8: KServe auto-recovers the predictor ---
Type "echo 'Waiting for KServe auto-recovery...' && sleep 30"
Enter
Sleep 31s

Type "oc get inferenceservice anomaly-detector -n self-healing-platform"
Enter
Sleep 3s

Type "oc get pods -n self-healing-platform -l serving.kserve.io/inferenceservice=anomaly-detector"
Enter
Sleep 3s

Type "echo '✅ Platform self-healed! Pod and model both recovered automatically.'"
Enter
Sleep 3s
