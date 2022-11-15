# typed: false
# frozen_string_literal: true

# This file was generated by Homebrew Releaser. DO NOT EDIT.
class HomebrewAwspm < Formula
  desc "Awspm, the aws profile manager, helps to set up your aws environment for deployi"
  homepage "https://github.com/spryfox-analytics/homebrew-awspm"
  url "https://github.com/spryfox-analytics/homebrew-awspm/archive/v0.0.15.tar.gz"
  sha256 "7448dfc6b52b883ebfda44bcf143fd5454c7445c312b732ca38dd71237a8d490"
  license ""

  depends_on "bash" => :build

  on_macos do

    on_arm do
      url "https://github.com/spryfox-analytics/homebrew-awspm/releases/download/v0.0.15/homebrew-awspm-0.0.15-darwin-arm64.tar.gz"
      sha256 "2deef3cddba86a0ff8697f5887c4499a323e5c3466969fa04ef72b65cad133ac"
    end
  end

  def install
    bin.install "awspm.sh" => "awspm"
  end
end
