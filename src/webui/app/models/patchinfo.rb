class Patchinfo < ActiveXML::Base
  class << self
    def make_stub( opt )
      "<patchinfo/>"
    end
  end

  def save
    path = self.init_options[:package] ? "/source/#{self.init_options[:project]}/#{self.init_options[:package]}/_patchinfo" : "/source/#{self.init_options[:package]}/_patchinfo"
    begin
      frontend = ActiveXML::Config::transport_for(:package)
      frontend.direct_http URI("#{path}"), :method => "POST", :data => self.dump_xml
      result = {:type => :note, :msg => "Patchinfo sucessfully updated!"}
    rescue ActiveXML::Transport::Error => e
      result = {:type => :error, :msg => "Saving Patchinfo failed: #{ActiveXML::Transport.extract_error_message( e )[0]}"}
    end

    return result
  end

  def is_maintainer? userid
    has_element? "person[@role='maintainer' and @userid = '#{userid}']"
  end

  def set_cve(cvelist)
    if self.each_CVE == nil
      self.add_element('CVE')
    end
    cvelist.each do |cve|
      self.each_CVE do |f|
        self.delete_element(f)
      end
    end
    for x in cvelist do
      cve = self.add_element('CVE')
      cve.text = x
    end
  end

  def set_buglist(buglist)
    if self.each_bugzilla == nil
      self.add_element('bugzilla')
    end
    buglist.each do |bug|
      self.each_bugzilla do |f|
        # delete all bugs
        self.delete_element(f)
      end
    end

    for x in buglist do
      bug = self.add_element('bugzilla')
      bug.text = x
    end
  end

  def set_packager(packager)
    self.delete_element('packager')
    cve_new = self.add_element('packager')
    cve_new.text = packager
  end

  def set_relogin(relogin)
    self.delete_element('relogin_needed')
    relog = self.add_element('relogin_needed')
    relog.text = relogin
  end

  def set_reboot(reboot)
    self.delete_element('reboot_needed')
    reboot_needed = self.add_element('reboot_needed')
    reboot_needed.text = reboot
  end

  def set_relogin(relogin)
    self.delete_element('relogin_needed')
    relog = self.add_element('relogin_needed')
    relog.text = relogin
  end
 
  def set_reboot(reboot)
    self.delete_element('reboot_needed')
    reboot_needed = self.add_element('reboot_needed')
    reboot_needed.text = reboot
  end
 
  def set_binaries(binaries, name)
    if self.each_binary == nil
      self.add_element('binaries')
    end
    self.each_binary do |b|
      # delete all binaries which already set
      self.delete_element(b)
    end
    
    for x in binaries do
      binary = self.add_element('binary')
      binary.text = x
    end

  end



end

