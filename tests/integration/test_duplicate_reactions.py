from acom_music_box import MusicBox, Reaction, ReactionRate, Conditions
from acom_music_box.reaction_list import ReactionList

import os
import csv
import math


class TestDuplicateReactions:
    def test_run(self):
        # set up dummy reactions
        abc123 = ReactionRate(Reaction("abc"), 12.3)
        def456 = ReactionRate(Reaction("def"), 45.6)
        abc789 = ReactionRate(Reaction("abc"), 78.9)

        # Pass: unique reaction names
        pass_reactions = ReactionList(name="Pass list", reactions=[abc123, def456])
        pass_conditions = Conditions(reaction_rates=pass_reactions)
        box_model = MusicBox(initial_conditions=pass_conditions)
        box_model.check_config("Loaded from string.")

        assert True, f"All is good."


if __name__ == "__main__":
    test = TestDuplicateReactions()
    test.test_run()

