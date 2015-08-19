module SunatraDeployer
  class DeployJob
    include SuckerPunch::Job

    def perform(repository:, branch:, callback_url:)

      Log.new(event).track
    end
  end
end
