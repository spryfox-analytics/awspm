# AWS Profile Manager

* Installation:
  * `brew tap spryfox-analytics/homebrew-awspm`
  * `brew install spryfox-analytics/awspm/homebrew-awspm`
* Usage:
  * `awspm init` - Configures the AWS account profiles.
  * `awspm profile` - Derives a profile name for the current folder.
  * `awspm test` - Checks whether a valid .aws_accounts file can be found.

* Build
  * Create a new classic token here: https://github.com/settings/tokens
  * Give 'repo' and 'write:packages' access
  * Update HOMEBREW_GITHUB_TOKEN here: https://github.com/spryfox-analytics/homebrew-awspm/settings/secrets/actions
  * Create a new tag in the IDE (e.g., v0.0.39) and push the tag
  * Once build is finished, delete the token again here: https://github.com/settings/tokens
