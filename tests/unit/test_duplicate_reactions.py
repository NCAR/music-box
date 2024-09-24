from acom_music_box import MusicBox, Reaction, ReactionRate, Conditions
from acom_music_box.reaction_list import ReactionList

import pytest


class TestDuplicateReactions:
    def test_run(self):
        # set up dummy reactions
        abc123 = ReactionRate(Reaction("abc"), 12.3)
        def456 = ReactionRate(Reaction("def"), 45.6)
        abc789 = ReactionRate(Reaction("abc"), 78.9)

        # Pass: unique reaction names
        pass_reactions = [abc123, def456]
        pass_conditions = Conditions(reaction_rates=pass_reactions)
        box_model = MusicBox(initial_conditions=pass_conditions)
        assert box_model.check_config("Loaded from string.")

        # Fail: duplicate reaction names
        fail_reactions = reactions=[abc123, abc789]
        fail_conditions = Conditions(reaction_rates=fail_reactions)
        box_model = MusicBox(initial_conditions=fail_conditions)    # new instance

        # verify that the fail exception was properly raised
        with pytest.raises(Exception):
            box_model.check_config("Loaded from string.")


if __name__ == "__main__":
    test = TestDuplicateReactions()
    test.test_run()

