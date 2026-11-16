package Terminal.App.System_Theme is
   type Preference is (Unknown, Prefer_Light, Prefer_Dark);

   --  BRACKE_TERMINAL_COLOR_SCHEME=light|dark is an explicit override.  When
   --  it is absent, Current consults the active toolkit environment and the
   --  user's GTK/KDE configuration without starting helper processes.
   function Current return Preference;
   function Image (Value : Preference) return String;
end Terminal.App.System_Theme;
