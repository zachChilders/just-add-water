# Next Steps

Now that you're up and running, here are some additional things to do in order
to maintain longterm security of your infrastructure.  These are things we would
have done for you, but Azure doesn't quite give us a way to automate it.  Check
back here often!

## Add Additional Owners

As good BCDR practice, you should have at least two Owner level users on your subscription.

1. [Add an additional user in AAD.](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/add-users-azure-active-directory)
1. [Add the Owner Role to your new User](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-users-assign-role-azure-portal)

## Add Additional Users to RBAC

When we provision your infrastructure, we create an RBAC group called `$namePrefixadmins`.
These users have control over your infrastructure, including secrets.  You can add more users
to help manage things.

[Add User to Groups](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-groups-members-azure-portal)

## Enable MFA

[Enable Multi-Factor Auth to prevent your accounts from being hijacked.](https://docs.microsoft.com/en-us/azure/active-directory/authentication/concept-mfa-get-started)

## Configure Azure Sentinel

Azure Sentinel is a SIEM to help monitor your subscriptions from bad guys.

It uses existing log sources to find Indicators of Compromise and will notify you of anything
nasty, or can be used to automate remediation.

Sentinel is a paid service, and you will be billed per GB of logs that it ingests.
For billing, see [Sentinel Pricing](https://azure.microsoft.com/en-us/pricing/details/azure-sentinel/)

1. [Create a Sentinel Workspace](https://aka.ms/microsoftazuresentinel)
1. Connect to the workspace we provisioned
1. [Connect datasources](https://docs.microsoft.com/en-us/azure/sentinel/connect-data-sources)
