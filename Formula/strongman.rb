# typed: false
# frozen_string_literal: true

class Strongman < Formula
  include Language::Python::Virtualenv

  desc "Web UI for managing strongSwan via VICI on macOS"
  homepage "https://github.com/strongswan/strongMan"
  url "https://github.com/strongswan/strongMan.git",
      using: :git,
      branch: "master"
  version "0.0.0+master"
  license "MIT"

  depends_on "python@3.12"
  depends_on "strongswan"

  resource "django" do
    url "https://files.pythonhosted.org/packages/c8/4c/7c74ba43f6ffcadfbd4e02eae4b3ed77e91be3b3abec64b1e1bbeca1a0a50/Django-4.2.25.tar.gz"
    sha256 "87e47d2b0e41715db97b01d9f5f3c5cf4e9cc8b5cefe7001e1e16a5bf3b5b4c3"
  end

  resource "requests" do
    url "https://files.pythonhosted.org/packages/c9/74/b3ff8e6c8446842c3f5c837e9c3dfcfe2018ea6ecef224c710c85ef728f4/requests-2.32.5.tar.gz"
    sha256 "dbba0bac56e100853db0ea71b82b4dfd5fe2bf6d3754a8893c3af500cec7d7cf"
  end

  resource "gunicorn" do
    url "https://files.pythonhosted.org/packages/cb/eb/4e3ce7a7ab27b484e9b51cb48b5651fc7a11c23f0ef7a4f39e01fb6c96d9/gunicorn-23.0.0.tar.gz"
    sha256 "f014447a0101dc57e294f6c18ca6b40227a4c90e9bdb586042628030cba004ec"
  end

  def install
    venv = virtualenv_create(libexec, "python3.12")
    venv.pip_install resources
    
    # Copy the strongMan source to make it importable
    site_packages = libexec/"lib/python3.12/site-packages"
    site_packages.install buildpath/"strongman"
    
    # Copy entire source tree to pkgshare for manage.py and static files
    pkgshare.install Dir["*"]

    # Runtime launcher script for gunicorn
    (libexec/"strongman-run").unlink if (libexec/"strongman-run").exist?
    (libexec/"strongman-run").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      export VICI_HOST="${VICI_HOST:-127.0.0.1}"
      export VICI_PORT="${VICI_PORT:-4502}"
      UI_BIND="${UI_BIND:-0.0.0.0:1515}"
      WORKERS="${GUNICORN_WORKERS:-2}"

      # Set Python path to include the strongMan source
      export PYTHONPATH="#{pkgshare}:${PYTHONPATH:-}"
      
      # Some strongMan setups expect to run from the project dir (for static/templates)
      cd "#{pkgshare}"
      exec "#{libexec}/bin/gunicorn" \\
        "strongman.wsgi:application" \\
        --bind "${UI_BIND}" \\
        --workers "${WORKERS}"
    EOS
    chmod 0755, libexec/"strongman-run"

    # Convenience CLI to run in foreground (optional)
    (bin/"strongman").unlink if (bin/"strongman").exist?
    (bin/"strongman").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/strongman-run" "$@"
    EOS
    chmod 0755, bin/"strongman"
  end

  service do
    run [opt_libexec/"strongman-run"]
    keep_alive true
    working_dir var
    log_path var/"log/strongman.log"
    error_log_path var/"log/strongman-error.log"
    environment_variables(
      "VICI_HOST" => "127.0.0.1",
      "VICI_PORT" => "4502",
      "UI_BIND" => "0.0.0.0:1515",
      "GUNICORN_WORKERS" => "2"
    )
  end

  def caveats
    <<~EOS
      1) Enable VICI in strongSwan (loopback-only):
         Intel: /usr/local/etc/strongswan.d/charon/vici.conf
         ARM:   /opt/homebrew/etc/strongswan.d/charon/vici.conf

         vici {
           socket = unix:///usr/local/var/run/charon.vici
           tcp = yes
           tcp_listen = 127.0.0.1
           tcp_port = 4502
         }

         Then:  sudo ipsec restart

      2) Start strongMan:
         brew services start strongman          # user agent (after login)
         sudo brew services start strongman     # system daemon (boot before login)

      3) First-time admin:
         cd #{opt_pkgshare}
         #{opt_libexec}/bin/python manage.py createsuperuser

      UI:  http://<host>:1515/
      Logs: #{var}/log/strongman.log , #{var}/log/strongman-error.log
    EOS
  end

  test do
    # Just confirm our wrapper is present and executable
    assert_predicate bin/"strongman", :executable?
  end
end