with Terminal.App.Graphics_Transport;
with Terminal.Core;

--  One immutable description of graphics features admitted by both the
--  parser-facing capability replies and the renderer security policy.
package Terminal.App.Graphics_Profile is
   type Runtime_Profile is private;

   function Create
     (Kitty_File_Transfer      : Boolean;
      Kitty_Temporary_Transfer : Boolean;
      Kitty_Shared_Memory      : Boolean;
      ITerm2_File_Downloads    : Boolean := False) return Runtime_Profile;

   function Default return Runtime_Profile;
   function Core_Capabilities
     (Value : Runtime_Profile)
      return Terminal.Core.Graphics_Capability_Profile;
   function Access_Policy
     (Value : Runtime_Profile)
      return Terminal.App.Graphics_Transport.Access_Policy;
   function Downloads_Enabled (Value : Runtime_Profile) return Boolean;

private
   type Runtime_Profile is record
      Core      : Terminal.Core.Graphics_Capability_Profile :=
        (others => False);
      Transport : Terminal.App.Graphics_Transport.Access_Policy :=
        (others => False);
      Downloads : Boolean := False;
   end record;
end Terminal.App.Graphics_Profile;
