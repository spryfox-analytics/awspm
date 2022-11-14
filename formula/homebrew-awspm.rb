class Awspm < Formula
  desc "awspm, the AWS Profile Manager, helps to set up your AWS environment for deploying IaC using a CoC folder structure."
  homepage "https://www.spryfox.de/"

  bottle :unneeded

  def install
    'bin.install "src/awspm.sh" => "awspm"'
  end
end