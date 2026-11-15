with Terminal.App.Platform_Media;

package body Terminal.App.Graphics_Profile is
   function Create
     (Kitty_File_Transfer      : Boolean;
      Kitty_Temporary_Transfer : Boolean;
      Kitty_Shared_Memory      : Boolean;
      ITerm2_File_Downloads    : Boolean := False) return Runtime_Profile
   is
      Files : constant Boolean :=
        Kitty_File_Transfer
          and then Terminal.App.Platform_Media.Local_File_Transfers_Available;
      Temporary : constant Boolean :=
        Kitty_Temporary_Transfer
          and then Terminal.App.Platform_Media.Local_File_Transfers_Available;
      Shared : constant Boolean :=
        Kitty_Shared_Memory
          and then Terminal.App.Platform_Media.Shared_Memory_Transfers_Available;
      Downloads : constant Boolean :=
        ITerm2_File_Downloads
          and then Terminal.App.Platform_Media.File_Downloads_Available;
   begin
      return
        (Core =>
           (Kitty_Direct_RGB         => True,
            Kitty_Direct_RGBA        => True,
            Kitty_Indexed_RGB        => True,
            Kitty_Indexed_RGBA       => True,
            Kitty_Direct_PNG         => True,
            Kitty_Direct_JPEG        => True,
            Kitty_Direct_GIF         => True,
            Kitty_Zlib_Compression   => True,
            Kitty_File_Transfer      => Files,
            Kitty_Temporary_Transfer => Temporary,
            Kitty_Shared_Memory      => Shared,
            Sixel                    => True,
            ITerm2_Inline_Images     => True,
            ITerm2_File_Downloads    => Downloads),
         Transport =>
           (Allow_Regular_Files   => Files,
            Allow_Temporary_Files => Temporary,
            Allow_Shared_Memory   => Shared),
         Downloads => Downloads);
   end Create;

   function Default return Runtime_Profile is
     (Create
        (Kitty_File_Transfer      => False,
         Kitty_Temporary_Transfer => True,
         Kitty_Shared_Memory      => True,
         ITerm2_File_Downloads    => False));

   function Core_Capabilities
     (Value : Runtime_Profile)
      return Terminal.Core.Graphics_Capability_Profile is (Value.Core);

   function Access_Policy
     (Value : Runtime_Profile)
      return Terminal.App.Graphics_Transport.Access_Policy is (Value.Transport);

   function Downloads_Enabled (Value : Runtime_Profile) return Boolean is
     (Value.Downloads);
end Terminal.App.Graphics_Profile;
