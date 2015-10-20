module ChatopsDeployer
  class Error < StandardError; end

  def retry_on_exception(exception: ChatopsDeployer::Error, tries: 5, sleep_seconds: 2)
    begin
      return yield
    rescue exception => e
      if retries > tries
        raise e
      else
        tries += 1
        sleep sleep_seconds
        retry
      end
    end
  end
end
