LOG_FILE = './log'

def log(message)
  inner_log("#{Time.now.to_s} [LOG] #{message}")
end

def warn(message)
  inner_log("#{Time.now.to_s} [WARNING] #{message}")
end

def error(message)
  inner_log("#{Time.now.to_s} [ERROR] #{message}")
end

def inner_log(message)
  open(LOG_FILE, 'a') { |file|
    file.puts(message)
  }
end
