import Foundation

enum AIPromptBuilder {

    static func buildSystemPrompt() -> String {
        """
        You are a fitness AI assistant that processes voice-recorded workout moments into structured data.

        Your job is to analyze voice transcripts from a strength training session and produce:
        1. A structured workout log (exercises, sets, reps, weights)
        2. Social media content (Instagram captions, tweet threads, reel scripts)
        3. Training insights and stories

        RULES FOR STRUCTURED LOG:
        - Normalize exercise names (e.g., "bench" → "Barbell Bench Press", "squats" → "Barbell Back Squat")
        - Default to lbs unless the user explicitly says kg
        - If a rep count or weight is ambiguous, provide your best guess and list it as an ambiguity
        - Group consecutive mentions of the same exercise together
        - Number sets sequentially within each exercise

        RULES FOR CONTENT:
        - Match the user's tone — if they're casual, be casual; if they're technical, be technical
        - Avoid generic fitness cliches ("no pain no gain", "beast mode", etc.)
        - Instagram captions should be < 2200 characters
        - Each tweet should be < 280 characters
        - Reel scripts should be 30-60 seconds when read aloud
        - Story cards should be brief, punchy insights
        - Hooks should be attention-grabbing first lines
        - Takeaways should be actionable lessons from the session

        RULES FOR INSIGHTS:
        - progressNote: Observations about progress, PRs, volume changes
        - formReminder: Form cues or technique notes the user mentioned
        - motivational: Encouraging notes based on effort or consistency
        - recovery: Notes about fatigue, soreness, or recovery needs

        Respond with valid JSON matching the schema exactly.
        """
    }

    static func buildUserPrompt(
        moments: [Moment],
        workoutDate: Date,
        duration: TimeInterval
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let durationMinutes = Int(duration / 60)

        var prompt = """
        WORKOUT SESSION
        Date: \(dateFormatter.string(from: workoutDate))
        Duration: \(durationMinutes) minutes
        Total moments recorded: \(moments.count)

        VOICE TRANSCRIPTS (in chronological order):
        """

        for (index, moment) in moments.enumerated() {
            let relativeTime = moment.timestamp.timeIntervalSince(workoutDate)
            let minutesIn = Int(relativeTime / 60)
            prompt += "\n[\(minutesIn)min] Moment \(index + 1): \"\(moment.transcript)\""
        }

        prompt += """

        \n
        Please analyze these voice transcripts and produce a JSON response with this structure:
        {
          "structuredLog": {
            "exercises": [
              {
                "id": "uuid-string",
                "exerciseName": "Exercise Name",
                "sets": [
                  {
                    "id": "uuid-string",
                    "setNumber": 1,
                    "reps": 10,
                    "weight": 135.0,
                    "weightUnit": "lbs",
                    "duration": null,
                    "notes": null
                  }
                ],
                "notes": null
              }
            ],
            "summary": "Brief workout summary",
            "highlights": ["Notable achievements"],
            "ambiguities": [
              {
                "id": "uuid-string",
                "field": "weight",
                "rawTranscript": "the original text",
                "bestGuess": "135 lbs",
                "alternatives": ["135 kg", "185 lbs"]
              }
            ]
          },
          "contentPack": {
            "igCaptions": ["Instagram caption 1"],
            "tweetThread": ["Tweet 1", "Tweet 2"],
            "reelScript": "Reel script text",
            "storyCards": [{"id": "uuid", "title": "Title", "body": "Body"}],
            "hooks": ["Hook line 1"],
            "takeaways": ["Takeaway 1"]
          },
          "stories": [
            {
              "id": "uuid-string",
              "title": "Story Title",
              "body": "Story body text",
              "tags": ["strength", "chest"],
              "type": "progressNote"
            }
          ]
        }
        """

        return prompt
    }
}
