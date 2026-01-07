require "paper_trail_hashdiff"
PaperTrail.config.object_changes_adapter = PaperTrailHashDiff.new
