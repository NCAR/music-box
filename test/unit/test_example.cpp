#include <gtest/gtest.h>

#include <music_box/music_box.hpp>

TEST(Example, GetMessage)
{
  auto message = music_box::get_message();
  ASSERT_EQ(message, "Hello, World!");
}