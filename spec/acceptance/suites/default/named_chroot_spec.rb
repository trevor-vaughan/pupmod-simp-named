require 'spec_helper_acceptance'

test_name 'named chroot'

describe 'named chroot' do
  let(:manifest) {
    <<-EOS
      include 'named::caching'

      named::caching::forwarders { '8.8.8.8': }
    EOS
  }

  hosts.each do |host|
    # Need this for the 'host' command
    host.install_package('bind-utils')

    context 'selinux setup' do
      selinux_enforcing = fact_on(host, 'selinux_enforcing')
      if selinux_enforcing
        on(host, 'setenforce permissive')
      end
    end

    context 'with internet connection' do
      it 'should work with no errors' do
        apply_manifest_on(host, manifest, :catch_failures => true)

        # verify chrooted service is up and running
        if host['roles'].include?('el6')
          on(host, 'service named status')
        else
          on(host, 'systemctl status named-chroot') do
            expect(stdout).to match /active \(running\)/
            expect(stdout).to match /\/etc\/systemd\/system\/named-chroot.service/
          end
        end
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be able to lookup www.google.com from itself' do
        on(host, 'echo -e "nameserver 127.0.0.1\nsearch `facter domain`" > /etc/resolv.conf')
        on(host, 'host www.google.com')
      end
    end
  end
end
