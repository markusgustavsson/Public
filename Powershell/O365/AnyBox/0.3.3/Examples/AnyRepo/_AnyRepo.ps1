Import-Module "..\..\AnyBox.psd1"
Import-Module PoshRSJob

if (-not $PSScriptRoot) {
  try {
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
  }
  catch {
    $PSScriptRoot = $PWD.Path
  }
}

$repos = @(Get-ChildItem -Path $PSScriptRoot -Directory)

if ($repos.Length -eq 0) {
  Write-Host 'No repos/scripts.'
  break
}

$repo = $null

if ($repos.Length -eq 1) {
  $repo = $repos[0]
}
else { # if ($repos.Length -gt 1) {
  # prompt for desired repo.
  $repo = $repos[0]
}

[string]$img_path = "$($repo.FullName)\banner.png"
if (-not (Test-Path $img_path)) {
  $img_path = $null
}

$cats = @($repo | Get-ChildItem -Directory -ea 0)
# $uncat_scripts = @($repo | Get-ChildItem -File -Filter '*.ps1')

[string]$sort_by = 'FullName'

$i = 0

$scripts = @($cats | select -PipelineVariable 'cat' | foreach {
  $cat | Get-ChildItem -File -Filter '*.ps1' -Recurse -ea 0 | sort -Property $sort_by |
    select BaseName, FullName, `
      @{Name='Tab';Expression={if ($cats.Length -gt 1) {$cat.BaseName} else {$null}}}, `
      @{Name='Group';Expression={$_.Directory.FullName.Replace($cat.FullName, '').TrimStart('\')}}
})

$prompts = New-Object AnyBox.Prompt[] ($scripts.Length)

for ($i = 0; $i -lt $scripts.Count; $i++) {
  $scripts[$i] = $scripts[$i] | select *, @{Name='id';Expression={"r_$i"}}
  $prompts[$i] = New-AnyBoxPrompt -Name $scripts[$i].id -Tab $scripts[$i].Tab -Group $scripts[$i].Group -RadioGroup 1 -ShowSeparator -ValidateSet $scripts[$i].BaseName -ShowSetAs Radio
}

$null = Show-AnyBox -Image $img_path -Prompts $prompts -CollapsibleGroups -CollapsedGroups `
-FontSize 13 -MinHeight 600 -MinWidth 400 -ResizeMode CanResizeWithGrip `
-PrepScript {
  function Get-ScriptPrompts
  {
    param([string]$FileName)

    [scriptblock]::Create($(Get-Content -Path $FileName -Raw)).Ast.ParamBlock | select -ExpandProperty Parameters | select Name, Attributes | foreach {
      [string]$name = $_.Name.VariablePath.UserPath
      $attrs = $_ | select -ExpandProperty Attributes #| where { @('Parameter', 'ValidateNotNull', 'ValidateNotNullOrEmpty') -contains $_.TypeName.Name }
      
      [bool]$mandatory = $false #$t | where { $_.TypeName.Name -eq 'Parameter' -and $_.NamedArguments -contains 'Mandatory'}
      [bool]$not_null = $false
      [AnyBox.InputType]$input_type = [AnyBox.InputType]::Text
      [scriptblock]$validate_script = $null
      [array]$validate_set = $null
      
      foreach ($attr in $attrs) {
        if ($attr.TypeName.Name -eq 'Parameter') {
          foreach ($arg in $attr.NamedArguments) {
            if ($arg.ArgumentName -eq 'Mandatory' -and $arg.Argument -eq $true -and -not $arg.ExpressionOmitted) {
              $mandatory = $true
              continue
            }
          }
        }
        elseif (@('ValidateNotNullOrEmpty', 'ValidateNotNull').Contains($attr.TypeName.Name)) {
          $not_null = $true
        }
        elseif ($attr.TypeName.Name -eq 'ValidateScript') {
          $validate_script = $attr.PositionalArguments[0].SafeGetValue() #.ScriptBlock
        }
        elseif ($attr.TypeName.Name -eq 'ValidateSet') {
          $validate_set = @($attr.PositionalArguments.SafeGetValue())
        }
        elseif ($attr.TypeName.Name -eq 'bool' -or $attr.TypeName.Name -eq 'switch') {
          $input_type = [AnyBox.InputType]::Checkbox
        }
        elseif ($attr.TypeName.Name -eq 'datetime') {
          $input_type = [AnyBox.InputType]::Date
        }
      }

      $default = $attrs | select -ExpandProperty Parent -First 1 | select -ExpandProperty DefaultValue | select -ExpandProperty Value
      
      $param_config = @{
        'InputType'=$input_type
        'Name'=$name
        'Message'=$name
        'ValidateNotEmpty'=($mandatory -or $not_null)
        'ValidateScript'=$validate_script
        'ValidateSet'=$validate_set
        'DefaultValue'=$default
      }

      New-AnyBoxPrompt @param_config -MessagePosition Left
    }
  }

  $watch = New-Object System.Windows.Threading.DispatcherTimer
  $watch.Interval = [timespan]::FromSeconds(1.0)
  $watch.Add_Tick({
    # if (-not $form.Window.IsVisible) {
    #   $watch.Stop()
    # }

    $done_jobs = @(Get-RSJob | where {$_.Completed})
  
    foreach ($job in $done_jobs)
    {
      $res = $null

      # $res = $job | Receive-RSJob -ErrorAction Stop -WarningAction Stop -InformationAction Continue
      [string]$icon = $null

      $out = $job | Where-Object { $_ } | Select-Object -ExpandProperty Output

      if ($job.HasErrors) {
        $err = $job | select -ExpandProperty Error
        $icon = 'Error'
        if ($out) {
          $out = 'StdOut:{0}{0}{1}{0}{0}StdErr:{0}{0}{2}' -f [environment]::NewLine, $out, $err
        }
        else {
          $out = $err.Exception.Message
        }
      }
      else {
        $icon = 'Information'
      }

      $job_name = '{0} (id: {1})' -f (@($job.Name[0..($job.Name.LastIndexOf('_')-1)]) -join ''), (@($job.Name[-4..-1]) -join '')
      $job | Remove-RSJob -Force

      # $exp_btn = New-AnyBoxButton -Text 'Explore' -ToolTip 'Explore data in a separate grid window.' -OnClick {
      #   $form['data_grid'].Items | Select-Object * | Out-GridView -Title 'Data'
      # }

      # $save_btn = New-AnyBoxButton -Text 'Save' -ToolTip 'Save data to a CSV file.' -OnClick {
      #   try {
      #     $savWin = New-Object Microsoft.Win32.SaveFileDialog
      #     $savWin.InitialDirectory = "$env:USERPROFILE\Desktop"
      #     $savWin.FileName = 'data.csv'
      #     $savWin.Filter = 'CSV File (*.csv)|*.csv'
      #     $savWin.OverwritePrompt = $true
      #     if ($savWin.ShowDialog()) {
      #       $form['data_grid'].Items | Export-Csv -Path $savWin.FileName -NoTypeInformation -Encoding ASCII -Force
      #       Start-Process -FilePath $savWin.FileName
      #     }
      #   }
      #   catch {
      #     $null = Show-AnyBox @childWinParams -Message $_.Exception.Message -Buttons 'OK'
      #   }
      # }

      # $copy_btn = New-AnyBoxButton -Text 'Copy' -ToolTip 'Copy message to clipboard' -OnClick {
      #   try {
      #     if (-not $form['Message'].Text) {
      #       $null = Show-AnyBox @childWinParams -Message 'There is no message to copy.' -Buttons 'OK'
      #     }
      #     else {
      #       [System.Windows.Clipboard]::SetDataObject($form['Message'].Text, $true)
      #       $null = Show-AnyBox @childWinParams -Message 'Successfully copied message to clipboard.' -Buttons 'OK'
      #     }
      #   }
      #   catch {
      #     $err_msg = "Error accessing clipboard:{0}{1}" -f [Environment]::NewLine, $_.Exception.Message
      #     $null = Show-AnyBox @childWinParams -Message $err_msg -Buttons 'OK'
      #   }
      # }

      $exp_btn = New-AnyBoxButton -Template 'ExploreGrid'
      $save_btn = New-AnyBoxButton -Template 'SaveGrid'
      $copy_btn = New-AnyBoxButton -Template 'CopyMessage'

      if ($out) {
        if ($out -is [array]) {
          $null = Show-AnyBox -Icon $icon -Title $job_name -Buttons @($exp_btn, $save_btn, 'OK') -MinWidth 300 -GridData $out -GridAsList:$($out.Length -eq 1)
        }
        elseif ($out -is [string] -or $out -is [int]) {
          $null = Show-AnyBox -Icon $icon -Title $job_name -Message $($out | Out-String) -Buttons @($copy_btn, 'OK') -MinWidth 300
        }
        else {
          $null = Show-AnyBox -Icon $icon -Title $job_name -Buttons @($exp_btn, $save_btn, 'OK') -MinWidth 300 -GridData @($out) -GridAsList:$(@($out).Length -eq 1)
        }
      }
      else {
        $null = Show-AnyBox -Icon $icon -Title $job_name -Message 'Script completed.' -Buttons 'OK' -MinWidth 300
      }
    }      
  })
  $watch.Start()
} `
-Buttons @(
  (New-AnyBoxButton -Text 'Close' -IsCancel),
  (New-AnyBoxButton -Text 'Jobs' -ToolTip 'View all jobs in queue.' -OnClick {
    $grid_data = @(Get-RSJob | select Id, Name, State, HasErrors, @{Name='LastActivity';Expression={$_.Runspace.LastActivity}})
    if (-not $grid_data) {
      Show-AnyBox @childWinParams -Message 'No jobs in queue.' -Buttons 'OK'
    }
    else {
      # $grid_data | Out-GridView -Title 'Jobs'
      $null = Show-AnyBox @childWinParams -GridData $grid_data -SelectionMode None -Buttons 'OK'
    }
  }),
  (New-AnyBoxButton -Text 'Start' -ToolTip 'Start the selected script.' -IsDefault -OnClick {
    $active_tab = $form['Tabs'].SelectedItem.Header.Text
    $inputs = $_
    $script = @($scripts | where { $_.Tab -eq $active_tab -and $inputs[$_.id] })[0]
    $prompts = @(Get-ScriptPrompts -FileName $script.FullName)
    $usr_params = @()
    if ($prompts.Length -gt 0) {
      $usr_input = Show-AnyBox -Prompts $prompts -Buttons 'Cancel', 'OK' -CancelButton 'Cancel' -DefaultButton 'OK' -ContentAlignment Center
      if ($usr_input['OK']) {
        $usr_params = @($prompts | foreach { $usr_input[$_.Name] })
      }
    }
    try {
      [string]$job_id = (@(0..9 | Get-Random -Count 4) -join '')
      [string]$job_name = '{0}_{1}' -f $script.BaseName, $job_id
      [string]$msg = "Execute '{0}' (id: {1})?" -f $script.BaseName, $job_id
      $ans = Show-AnyBox @childWinParams -Message $msg -Buttons 'No', 'Yes' -CancelButton 'No' -DefaultButton 'Yes' -ContentAlignment Center
      if ($ans['Yes']) {
        $null = Start-RSJob -Batch '1' -Name $job_name -Throttle 10 -FilePath $script.FullName -ArgumentList $usr_params
      }
    }
    catch {
      Show-AnyBox @childWinParams -Message $_.Exception.Message -Buttons 'OK'
    }
  })
)
