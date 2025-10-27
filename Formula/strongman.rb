class Strongman < Formula
  include Language::Python::Virtualenv

  desc "Web-based strongSwan IPsec VPN management interface"
  homepage "https://github.com/strongswan/strongMan"
  url "https://github.com/strongswan/strongMan.git", branch: "master"
  version "1.0.0"
  license "GPL-3.0-or-later"

  depends_on "python@3.13"

  resource "Django" do
    url "https://files.pythonhosted.org/packages/de/f1/230c6c20a77f8f1812c01dfd0166416e7c000a43e05f701b0b83301ebfc1/django-4.2.25.tar.gz"
    sha256 "2391ab3d78191caaae2c963c19fd70b99e9751008da22a0adcc667c5a4f8d311"
  end

  resource "gunicorn" do
    url "https://files.pythonhosted.org/packages/34/72/9614c465dc206155d93eff0ca20d42e1e35afc533971379482de953521a4/gunicorn-23.0.0.tar.gz"
    sha256 "f014447a0101dc57e294f6c18ca6b40227a4c90e9bdb586042628030cba004ec"
  end

  resource "vici" do
    url "https://files.pythonhosted.org/packages/bd/bb/aca7726ef14d59d6a76f29dd61578a7877c73bd872d84d6f30dd58559a78/vici-5.8.4.tar.gz"
    sha256 "50156fa12219789c416e35729fa05f808a8e8c63e6baec79b2bb2991cffe53c0"
  end

  resource "asn1crypto" do
    url "https://files.pythonhosted.org/packages/de/cf/d547feed25b5244fcb9392e288ff9fdc3280b10260362fc45d37a798a6ee/asn1crypto-1.5.1.tar.gz"
    sha256 "13ae38502be632115abf8a24cbe5f4da52e3b5231990aff31123c805306ccb9c"
  end

  resource "pyaes" do
    url "https://files.pythonhosted.org/packages/44/66/2c17bae31c906613795711fc78045c285048168919ace2220daa372c7d72/pyaes-1.6.1.tar.gz"
    sha256 "02c1b1405c38d3c370b085fb952dd8bea3fadcee6411ad99f312cc129c536d8f"
  end

  resource "django-tables2" do
    url "https://files.pythonhosted.org/packages/4b/89/e3a4dae972a4194f7ab83aa412fe56bf56c122eafe0fc7e6e34eb2749dc2/django-tables2-2.3.4.tar.gz"
    sha256 "50ccadbd13740a996d8a4d4f144ef80134745cd0b5ec278061537e341f5ef7a2"
  end

  resource "dj-static" do
    url "https://files.pythonhosted.org/packages/2b/8f/77a4b8ec50c821193bf9682c7896f12fd0418eb3711a7d66796ede59c23b/dj-static-0.0.6.tar.gz"
    sha256 "032ec1c532617922e6e3e956d504a6fb1acce4fc1c7c94612d0fda21828ce8ef"
  end

  resource "oscrypto" do
    url "https://github.com/wbond/oscrypto/archive/1547f535001ba568b239b8797465536759c742a3.tar.gz"
    sha256 "5855d4cc18172513c6b2c6dde00b89731faa907c7003d4965862f2f2e0fb9ae4"
  end

  def install
    # Create the virtualenv and install dependencies only
    venv = virtualenv_create(libexec, "python3.13")
    venv.pip_install resources
    
    # Create configuration directory
    (etc/"strongman").mkpath
    
    # Create data directories
    (var/"lib/strongman").mkpath
    (var/"log/strongman").mkpath

    # Install Django project files to libexec
    libexec.install "strongMan"
    
    # Create wrapper script for manage.py
    (bin/"strongman").write_env_script libexec/"bin/python", libexec/"strongMan/manage.py",
      :PYTHONPATH => libexec,
      :STRONGMAN_SECRET_KEY => "homebrew-default-key-change-in-production",
      :STRONGMAN_DEBUG => "False",
      :STRONGMAN_DATABASE_PATH => var/"lib/strongman/db.sqlite3",
      :STRONGMAN_LOG_DIR => var/"log/strongman",
      :DJANGO_ALLOWED_HOSTS => "*"
  end

  service do
    run [opt_bin/"strongman", "runserver", "0.0.0.0:1515"]
    working_dir var/"lib/strongman"
    log_path var/"log/strongman/stdout.log"
    error_log_path var/"log/strongman/stderr.log"
  end

  def post_install
    # Initialize database
    system bin/"strongman", "migrate", "--noinput"
    
    puts "=== strongMan Installation Complete ==="
    puts ""
    puts "1. Create admin user: #{bin}/strongman createsuperuser"
    puts "2. Start server: brew services start strongman"
    puts "3. Access locally: http://127.0.0.1:1515"
    puts "4. Access remotely: http://YOUR_SERVER_IP:1515"
    puts ""
    puts "SECURITY WARNING: Change STRONGMAN_SECRET_KEY for production!"
    puts "VICI Setup: Ensure strongSwan is running with VICI socket enabled"
    puts ""
    puts "Config files:"
    puts "- strongSwan: /usr/local/etc/ipsec.conf"
    puts "- VICI socket: /var/run/charon.vici (requires root or group access)"
  end

  test do
    # Test that Django can load the application
    system bin/"strongman", "check"
    
    # Test help command
    system bin/"strongman", "help"
  end
end
