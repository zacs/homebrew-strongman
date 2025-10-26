# typed: false
# frozen_string_literal: true

class Strongman < Formula
  include Language::Python::Virtualenv

  desc "Web UI for managing strongSwan via VICI on macOS"
  homepage "https://github.com/strongswan/strongMan"
  url "https://github.com/strongswan/strongMan.git",
      using: :git,
      branch: "master"
  # If you want to pin to a specific commit for stability, replace the line above with:
  # url "https://github.com/strongswan/strongMan.git",
  #     using: :git,
  #     revision: "PUT_FULL_COMMIT_SHA_HERE"

  # No upstream tags; keep version synthetic so brew can track upgrades in your tap.
  version "0.0.0+master"
  license "MIT"

  depends_on "python@3.12"
  depends_on "git"
  depends_on "strongswan"
  depends_on "pkg-config"
  depends_on "openssl@3"

  def install
    # Create a dedicated virtualenv
    venv = virtualenv_create(libexec, "python3.12")

    # Upgrade base tools and install deps with proper error handling
    system libexec/"bin/pip", "install", "--upgrade", "pip"
    system libexec/"bin/pip", "install", "--upgrade", "wheel", "setuptools"

    # Install gunicorn first as it's needed for the service
    system libexec/"bin/pip", "install", "gunicorn"

    # If the repo has a requirements.txt, install it; otherwise pip will resolve from setup.py
    reqs = buildpath/"requirements.txt"
    if reqs.exist?
      system libexec/"bin/pip", "install", "-r", reqs
    else
      # Install the app itself and its dependencies
      system libexec/"bin/pip", "install", "."
    end

    # Keep a copy of the sources (handy for manage.py tasks like createsuperuser/migrations)
    pkgshare.install Dir["*"]

    # Runtime launcher script for gunicorn
    (libexec/"strongman-run").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      export VICI_HOST="${VICI_HOST:-127.0.0.1}"
      export VICI_PORT="${VICI_PORT:-4502}"
      UI_BIND="${UI_BIND:-0.0.0.0:1515}"
      WORKERS="${GUNICORN_WORKERS:-2}"

      # Some strongMan setups expect to run from the project dir (for static/templates)
      cd "#{pkgshare}"
      exec "#{libexec}/bin/gunicorn" \
        "strongman.wsgi:application" \
        --bind "${UI_BIND}" \
        --workers "${WORKERS}"
    EOS
    chmod 0755, libexec/"strongman-run"

    # Convenience CLI to run in foreground (optional)
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