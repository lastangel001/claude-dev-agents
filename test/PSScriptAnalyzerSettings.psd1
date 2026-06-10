@{
    # Exclude rules that are intentional or inapplicable for this installer script.
    ExcludeRules = @(
        # Installer intentionally uses Write-Host for user-facing progress output.
        'PSAvoidUsingWriteHost',
        # Helper functions To-Rel and Record do not follow PS approved-verb naming;
        # they are private, short-lived helpers, not exported cmdlets.
        'PSUseApprovedVerbs',
        # Backup-IfExists is a private helper, not an exported cmdlet; "Exists"
        # is not a plural noun.
        'PSUseSingularNouns'
    )
}
