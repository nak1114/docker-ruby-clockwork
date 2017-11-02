if ENV['RACK_ENV']
#in docker

else
#in host

  name=File.basename(Dir.pwd)
  docker_run=%(docker run --rm -it -v "#{Dir.pwd}":/myapp -v /volume1/public/dl:/dl -e RACK_ENV=development -e RUBYOPT=-EUTF-8 #{name})

  desc "build new docker image"
  task :build , ['tag']  do |task, args|
    tag=args[:tag] || "0.0.1"
    touch('Gemfile.lock') unless File.exists?('Gemfile.lock')
    sh("docker build -t #{name}:#{tag} .")
    sh("docker tag #{name}:#{tag} #{name}:latest")
    sh("#{docker_run} cp -pf /tmp/Gemfile.lock /myapp")
  end

  desc "run app in docker"
  task :run  do |task, args|
    sh("#{docker_run.sub('docker run','docker run')}")
  end

  desc "run 'bash' in docker"
  task :bash  do |task, args|
    sh("#{docker_run} /bin/bash")
  end

  desc "run 'pry' in docker"
  task :pry do
    sh("#{docker_run} bundle exec pry")
  end

end
