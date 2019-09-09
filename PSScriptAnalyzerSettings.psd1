@{
  Severity = @(
    'Error',
    'Warning',
    'Information'
  )
  Rules    = @{
    PSAvoidUsingCmdletAliases = @{
      # only whitelist verbs from *-Object cmdlets
      Whitelist = @(
        '%',
        '?',
        'compare',
        'foreach',
        'group',
        'measure',
        'select',
        'tee',
        'where'
      )
    }
    PSProvideCommentHelp      = @{
      Enable                  = $true
      ExportedOnly            = $true
      BlockComment            = $true
      VSCodeSnippetCorrection = $true
      Placement               = "before"
    }
  }
}