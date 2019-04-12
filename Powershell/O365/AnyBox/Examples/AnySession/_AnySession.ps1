Import-Module "..\..\AnyBox.psd1"

$cats = @($PSScriptRoot | Get-ChildItem -Directory -ea 0)
# $uncat_scripts = @($repo | Get-ChildItem -File -Filter '*.ps1')

[string]$sort_by = 'FullName'

$i = 0

$pc_list = @($cats | select -PipelineVariable 'cat' | foreach {
  $cat | Get-ChildItem -File -Filter '*.txt' -Recurse -ea 0 | sort -Property $sort_by | foreach {
    $file_name = $_.BaseName
      $_ | Get-Content | where { -not $_.StartsWith('#') } |
        select @{Name='ComputerName';Expression={$_.Trim()}}, `
            @{Name='Tab';Expression={if ($cats.Length -gt 1) {$cat.BaseName} else {$null}}}, `
            @{Name='Group';Expression={$file_name}}
  }
})

$prompts = New-Object AnyBox.Prompt[] ($pc_list.Length)

for ($i = 0; $i -lt $pc_list.Count; $i++) {
  $pc_list[$i] = $pc_list[$i] | select *, @{Name='id';Expression={"pc_$i"}}
  $prompts[$i] = New-AnyBoxPrompt -Name $pc_list[$i].id -Tab $pc_list[$i].Tab -Group $pc_list[$i].Group -Message $pc_list[$i].ComputerName -InputType Checkbox
}

$clear_all = New-AnyBoxButton -Text 'Clear All' -OnClick {
  $active_tab = $form['Tabs'].SelectedItem.Header.Text
  $inputs = $_
  $pcs = @($pc_list | where { $_.Tab -eq $active_tab -and $inputs[$_.id] })
  foreach ($pc in $pcs) {
    $form[$pc.id].IsChecked = $false
    $inputs[$pc.id] = $false
  }
}

$select_all = New-AnyBoxButton -Text 'Select All' -OnClick {
  $active_tab = $form['Tabs'].SelectedItem.Header.Text
  $inputs = $_
  $pcs = @($pc_list | where { $_.Tab -eq $active_tab -and -not $inputs[$_.id] })
  foreach ($pc in $pcs) {
    $form[$pc.id].IsChecked = $true
    $inputs[$pc.id] = $true
  }
}

$enter_sess = New-AnyBoxButton -Text "PSSession" -OnClick {
  $active_tab = $form['Tabs'].SelectedItem.Header.Text
  $inputs = $_
  $pcs = @($pc_list | where { $_.Tab -eq $active_tab -and $inputs[$_.id] })
  foreach ($pc in $pcs) {
    Start-Process -FilePath 'powershell' -ArgumentList $('-NoExit -Command "& {{ Enter-PSSession -ComputerName {0} }}"' -f $pc.ComputerName)
  }
}

$run_script = New-AnyBoxButton -Text 'PS Script' -OnClick {
  $ans = Show-AnyBox @childWinParams -Buttons 'Cancel', 'Continue' -CancelButton 'Cancel' -DefaultButton 'Continue' -Prompts @(
    (New-AnyBoxPrompt -Name 'file' -InputType FileOpen -ReadOnly -ValidateScript {
      [string]$ext = Get-Item $_ -ea 0 | select -ExpandProperty 'Extension'
      return($ext.ToLower() -eq '.ps1')
    }),
    (New-AnyBoxPrompt -Name 'method' -ValidateSet @('Run Script in PSSessions', 'Pass Selections as Parameter') `
      -DefaultValue 'Run Script in PSSessions' -ShowSetAs Radio)
  )

  if ($ans['Continue']) {
    if (-not (Test-Path $ans['file'])) {
      # error
    }
    elseif ($ans['method'] -eq 'Run Script in PSSessions') {
      $active_tab = $form['Tabs'].SelectedItem.Header.Text
      $inputs = $_
      $pcs = @($pc_list | where { $_.Tab -eq $active_tab -and $inputs[$_.id] })
      Invoke-Command -ComputerName $pcs -FilePath $ans['file'] -ErrorAction Stop
    }
    elseif ($ans['method'] -eq 'Pass Selections as Parameter') {
      Invoke-Command -FilePath $ans['file'] -ArgumentList @(,$pcs) -ErrorAction Stop
    }
  }
}

# 'Run Script (WinRM)', 'Run Script (Local)' 

Show-AnyBox -Prompts $prompts -CollapsibleGroups -CollapsedGroups -Buttons @($clear_all, $select_all, $enter_sess, $run_script) -ButtonRows 2 `
  -FontSize 13 -MinHeight 600 -MinWidth 400 -ResizeMode CanResizeWithGrip
