# typed: false
# frozen_string_literal: true

class Strongman < Formula
  include Language::Python::Virtualenv

  desc "Web UI for managing strongSwan via VICI on macOS"
  homepage "https://github.com/strongswan/strongMan"
  url "https://github.com/strongswan/strongMan.git",
      using: :git,
      tag: "v1.0.0"
  version "1.0.0"
  license "MIT"

  depends_on "python@3.12"
  depends_on "git"
  depends_on "strongswan"

  def install
    # Create virtualenv and install all Python dependencies
    venv = virtualenv_create(libexec, "python3.12")
    system libexec/"bin/pip", "install", "--upgrade", "pip", "wheel"
    system libexec/"bin/pip", "install", "-r", "requirements.txt"
    system libexec/"bin/pip", "install", "gunicorn"

    # Copy app into pkgshare
    pkgshare.install Dir["*"]

    # Runtime launcher script
    (libexec/"strongman-run").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      export VICI_HOST="${VICI_HOST:-127.0.0.1}"
      export VICI_PORT="${VICI_PORT:-4502}"
      UI_BIND="${UI_BIND:-0.0.0.0:1515}"
      WORKERS="${GUNICORN_WORKERS:-2}"
      exec "#{libexec}/bin/gunicorn" \\
        "strongman.wsgi:application" \\
        --bind "${UI_BIND}" \\
        --workers "${WORKERS}" \\
        --chdir "#{pkgshare}"
    EOS
    chmod 0755, libexec/"strongman-run"

    # CLI shortcut
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
      ✅ strongMan installed successfully!

      1️⃣ Enable VICI plugin in strongSwan (keep it loopback-only):
          Intel: /usr/local/etc/strongswan.d/charon/vici.conf
          ARM:   /opt/homebrew/etc/strongswan.d/charon/vici.conf

          vici {
            socket = unix:///usr/local/var/run/charon.vici
            tcp = yes
            tcp_listen = 127.0.0.1
            tcp_port = 4502
          }

          sudo ipsec restart

      2️⃣ Start strongMan (web UI for strongSwan):
          brew services start strongman          # user-level
          sudo brew services start strongman     # system-level (boot before login)

      3️⃣ Access it at:
          http://localhost:1515/

      4️⃣ Create your first admin user:
          cd #{opt_pkgshare}
          #{libexec}/bin/python manage.py createsuperuser

      Logs:
          #{var}/log/strongman.log
          #{var}/log/strongman-error.log

      To stop:
          brew services stop strongman
    EOS
  end

  test do
    assert_match "gunicorn", shell_output("#{bin}/strongman --help", 0)
  end
end