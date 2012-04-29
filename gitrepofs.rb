
require 'rubyfuse'
require 'rugged'

class GitRepoDir

  def initialize(path)
    @repo = Rugged::Repository.new(path)
    init_refdirs
    puts "@refdirs = #{@refdirs.inspect}"
  end
  
  def init_refdirs
    @refdirs = Hash.new do |h,k|
      list = []
      @repo.refs.each do |str|
        if str =~ /^\/?refs\/#{k}\/(.*)$/
          list << $1.gsub(/\//, '\\')
        end
      end
      h[k] = list
    end
  end
  
  def error(str)
    puts "ERROR: #{str}"
    raise(str)
  end
  
  def reftypes
    ['tags', 'heads']
  end
  
  def get_tree_by_refpath(reftype, refpath)
    refpath.gsub!(/\\/, '/')
    reflookup = "refs/#{reftype}/#{refpath}"
    puts "reflookup = #{reflookup}"
    ref = Rugged::Reference.lookup(@repo, reflookup) or error "Cannot find ref #{reflookup.inspect}"
    puts "ref.target=#{ref.target}"
    commit = @repo.lookup(ref.target) or error "Cannot find commit for ref target #{reflookup}=#{ref.target.inspect}"
    commit = commit.target if(commit.type == 'tag')
    tree = commit.tree or error "Not a tree: #{commit.inspect}"
    puts "tree = #{tree.inspect}"
    tree
  end
  
  def subtree(tree, dirname, &bl)
    data = tree[dirname] and oid = data[:oid] and @repo.lookup(oid)
  end
  
  def contents(path)
    paths = path.split('/')
    puts "paths = #{paths.inspect}"
    paths.shift
    if(reftype = paths.shift)
      if(refpath = paths.shift)
        res = []
        tree = get_tree_by_refpath(reftype, refpath)
        while(tree && subdir = paths.shift)
          tree = subtree(tree, subdir)
        end
        if tree
          tree.each {|entry| res << entry[:name] }
        end
        puts "res = #{res.inspect}"
        res
      else
        @refdirs[reftype]
      end
    else
      reftypes
    end
  end
  
  def file?(path)
    paths = path.split('/')
    paths.shift
    puts "file?(#{paths.inspect})"
    res = if(reftype = paths.shift)
      if reftypes.include?(reftype)
        if(refpath = paths.shift)
          tree = get_tree_by_refpath(reftype, refpath)
          while(tree && subdir = paths.shift)
            puts "  looking up subdir=#{subdir}"
            tree = subtree(tree, subdir)
          end
          if(tree && tree.type == 'blob')
            tree
          end
        end
      end
    end
    puts "  = #{res.inspect}"
    res
  end
  def directory?(path)
    paths = path.split('/')
    paths.shift
    puts "directory?(#{paths.inspect})"
    res = if(reftype = paths.shift)
      if reftypes.include?(reftype)
        if(refpath = paths.shift)
          tree = get_tree_by_refpath(reftype, refpath)
          while(tree && subdir = paths.shift)
            puts "  looking up subdir=#{subdir}"
            tree = subtree(tree, subdir)
          end
          tree && tree.type == 'tree'
        else
          true
        end
      end
    else
      true
    end
    puts "  = #{res.inspect}"
    res
  end
  def size(path)
    if obj = file?(path)
      obj.size.to_i
    end
  end
  def read_file(path)
    if obj = file?(path)
      obj.content
    end

  end
end

gitrepofs = GitRepoDir.new(ARGV.shift)
RubyFuse.set_root(gitrepofs)

RubyFuse.mount_under ARGV.shift
RubyFuse.run

