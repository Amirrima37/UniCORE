param([Parameter(Mandatory=$true)][int]$ProcessId,[string]$Output='docs/hpc-optimization/hpc24-waits.json',[ValidateRange(1,10)][int]$Seconds=10)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $Output){throw 'Choose a new report path'}
$rows=@();$timer=[Diagnostics.Stopwatch]::StartNew()
while($timer.Elapsed.TotalSeconds -lt $Seconds){
 try{
  $proc=Get-Process -Id $ProcessId -ErrorAction Stop
  $threads=@(foreach($thread in $proc.Threads){$state=$thread.ThreadState.ToString();$reason=$null;if($state -eq 'Wait'){try{$reason=$thread.WaitReason.ToString()}catch{}};@{id=$thread.Id;state=$state;wait_reason=$reason}})
  $rows+=@{elapsed_s=$timer.Elapsed.TotalSeconds;cpu_s=$proc.CPU;working_set=$proc.WorkingSet64;peak_working_set=$proc.PeakWorkingSet64;paged_memory=$proc.PagedMemorySize64;threads=$threads}
 }catch{break}
 Start-Sleep -Milliseconds 100
}
ConvertTo-Json -Depth 6 -InputObject $rows | Set-Content -LiteralPath $Output
# This read-only sampler neither starts nor terminates the observed process.
# Wait reasons are observations, not proof of the source of an off-CPU delay.
