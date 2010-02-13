require 'net/ftp'
require 'net/ftp/list'
require 'FileUtils'

class FtpSync
  attr_reader :connection
  
  def initialize(server, user, password, ignore = nil)
    @server = server
    @user = user
    @password = password
    @connection = nil
    @ignore = ignore
    @recursion_level = 0
  end
  
  def pull_dir(localpath, remotepath)
    connect!
    @recursion_level += 1
    
    tocopy = []
    recurse = []
    @connection.list(remotepath) do |entry|
      paths = [ File.join(localpath, entry.basename), "#{remotepath}/#{entry.basename}" ]
      if entry.dir?
        recurse << paths
      elsif entry.file?
        tocopy << paths
      end
    end
    
    tocopy.each do |paths|
      localfile, remotefile = paths
      @connection.get(remotefile, localfile)
    end
    
    recurse.each do |paths|
      localdir, remotedir = paths
      Dir.mkdir(localdir) unless File.exist?(localdir)
      pull_dir(localdir, remotedir)
    end
    
    @recursion_level -= 1
    close! if @recusion_level == 0
  end
  
  def push_dir(localpath, remotepath)
    connect!
    
    Dir.glob(File.join(localpath, '**', '*')) do |f|
      f.gsub!("#{localpath}/", '')
      local = File.join localpath, f
      remote = "#{remotepath}/#{f}"
      
      if File.directory?(local)
        @connection.mkdir remote rescue Net::FTPPermError
      elsif File.file?(local)
        @connection.put local, remote
      end
    end
    
    close!
  end
  
  def pull_files(localpath, remotepath, filelist)
    connect!
    filelist.each do |f|
      FileUtils.mkdir_p File.join(localpath, File.dirname(f))
      @connection.get "#{remotepath}/#{f}", File.join(localpath, f)
    end
    close!
  end
  
  def push_files(localpath, remotepath, filelist)
    connect!
    
    remote_paths = filelist.map {|f| File.dirname(f) }.uniq
    create_remote_paths(remotepath, remote_paths)
    
    filelist.each do |f|
      @connection.put File.join(localpath, f), "#{remotepath}/#{f}"
    end
    close!
  end
  
  private
    def connect!
      @connection = Net::FTP.new(@server)
      @connection.login(@user, @password)
    end
  
    def close!
      @connection.close
    end
    
    def create_remote_paths(base, pathlist)
      pathlist.each do |remotepath|
        parent = base
        remotepath.split('/').each do |p|
          parent = "#{parent}/#{p}"
          @connection.mkdir(parent) rescue Net::FTPPermError
        end
      end
    end
end