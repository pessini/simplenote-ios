# frozen_string_literal: true

# Notice the plural in the name.
# The action this method calls may create multiple backmerge PRs, depending on how many release branches with version greater than the source are in the remote.
#
def create_backmerge_prs!(
  version: release_version_current,
  source_branch: release_branch_name(release_version: version),
  labels: ['Releases'],
  milestone_title: release_version_next
)
  begin
    pr_urls = create_release_backmerge_pull_request(
      repository: GITHUB_REPO,
      source_branch: source_branch,
      labels: labels,
      milestone_title: milestone_title
    )
  rescue StandardError => e
    error_message = create_backmerge_error_message(error: e, version: version)

    buildkite_annotate(style: 'error', context: 'error-creating-backmerge', message: error_message) if is_ci

    UI.user_error!(error_message)
  end

  # It's possible that no backmerge was created when:
  #
  # - there are no hotfixes in development and the next release code freeze has not been started
  # - nothing changes in the current release branch since release finalization
  #
  # As a matter of fact, in the context of Simplenote Android, the above is the most likely scenario.
  style = pr_urls.empty? ? 'info' : 'success'
  message = create_backmerge_success_message(pr_urls: pr_urls)

  buildkite_annotate(style: style, context: 'backmerge-prs-outcome', message: message) if is_ci

  UI.success(message)

  pr_urls
end

def create_backmerge_error_message(error:, version:)
  <<~MESSAGE
    Error creating backmerge pull request(s):

    #{error.message}

    If this is not the first time you are running the release task, the backmerge PR(s) for the version `#{version}` might have already been previously created.
    Please close any pre-existing backmerge PR for `#{version}`, delete the previous merge branch, then run the release task again.
  MESSAGE
end

def create_backmerge_success_message(pr_urls:)
  if pr_urls.empty?
    'No backmerge PR was required.'
  else
    <<~MESSAGE
      The following backmerge PR#{pr_urls.length > 1 ? '(s) were' : ' was'} created:

      #{pr_urls.map { |url| "- #{url}" }.join("\n")}
    MESSAGE
  end
end

# Marks a GitHub release milestone as completed (i.e. removes the frozen marker from the name) and closes it.
#
def mark_github_release_milestone_as_completed(repository:, release_version:)
  UI.message("Attempting to close the milestone for version #{release_version}...")

  set_milestone_frozen_marker(
    repository: repository,
    milestone: release_version,
    freeze: false
  )
  close_milestone(
    repository: repository,
    milestone: release_version
  )

  UI.message("Successfully closed the milestone for version #{release_version}.")
rescue StandardError => e
  report_milestone_error(error_title: "Error in milestone finalization process for `#{release_version}`: #{e.message}")
end

def report_milestone_error(error_title:)
  error_message = <<-MESSAGE
    #{error_title}
    - If this is not the first time you are running the release task (e.g. retrying because it failed on first attempt), the milestone might have already been closed and this error is expected.
    - Otherwise, please investigate the error.
  MESSAGE

  UI.error(error_message)

  buildkite_annotate(style: 'warning', context: 'error-with-milestone', message: error_message) if is_ci
end

# Delete a branch from the GitHub remote, after having removed any GitHub branch protection.
#
def delete_remote_git_branch!(branch_name, remote: 'origin')
  remove_branch_protection(repository: GITHUB_REPO, branch: branch_name)

  Git.open(Dir.pwd).push(remote, branch_name, delete: true)
end
