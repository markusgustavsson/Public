Import-Module PoshRSJob

cd $(Get-Module AnyBox).ModuleBase

function Get-ScriptPrompts
{
  param([string]$FileName)

  $sb = [scriptblock]::Create($(Get-Content -Path $FileName -Raw))

  $params = $sb.Ast.ParamBlock | select -ExpandProperty Parameters | select Name, Attributes

  [array]$prompts = @($params | foreach {
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
      elseif ($attr.TypeName.Name -eq 'bool') {
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
  })
}

$usr_input = Show-AnyBox -Prompts $prompts -Buttons 'Cancel', 'OK' -CancelButton 'Cancel' -DefaultButton 'OK' -ContentAlignment Center

if ($usr_input['OK']) {
  [array]$usr_params = @($prompts | foreach { $usr_input[$_.Name] })
  $j = Start-RSJob -ScriptBlock $sb -ArgumentList $usr_params
  $j | Wait-RSJob | Out-Null
  $j | Receive-RSJob
  $j | Remove-RSJob
}

# select -ExpandProperty Attributes |
# select -ExpandProperty NamedArguments