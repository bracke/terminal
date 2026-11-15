with Terminal.App.Theme;

package Terminal.App.Session_Profiles is
   Max_Profiles : constant := 16;
   Max_Name_Length : constant := 32;
   Max_Value_Length : constant := 1_024;
   Max_Launch_Command_Length : constant := 3_000;

   type Profile is private;
   type Registry is private;

   procedure Apply_Field
     (Profiles : in out Registry;
      Key      : String;
      Value    : String;
      Accepted : out Boolean);
   procedure Set_Default
     (Profiles : in out Registry;
      Name     : String;
      Accepted : out Boolean);

   function Count (Profiles : Registry) return Natural;
   function Item (Profiles : Registry; Index : Positive) return Profile;
   function Default_Index (Profiles : Registry) return Natural;
   function Find (Profiles : Registry; Name : String) return Natural;

   function Name (Value : Profile) return String;
   function Working_Directory (Value : Profile) return String;
   function Command (Value : Profile) return String;
   function Shell (Value : Profile) return String;
   function Environment (Value : Profile) return String;
   function SSH_Host (Value : Profile) return String;
   function Theme_Name (Value : Profile) return String;
   function Launch_Command (Value : Profile) return String;

private
   type Text_Value is record
      Length : Natural range 0 .. Max_Value_Length := 0;
      Text   : String (1 .. Max_Value_Length) := (others => ' ');
   end record;
   type Profile is record
      Profile_Name : Text_Value;
      CWD          : Text_Value;
      Start        : Text_Value;
      Shell_Path   : Text_Value;
      Env          : Text_Value;
      Host         : Text_Value;
      Theme        : Text_Value;
   end record;
   type Profile_Array is array (Positive range 1 .. Max_Profiles) of Profile;
   type Registry is record
      Length       : Natural range 0 .. Max_Profiles := 0;
      Default_Name : Text_Value;
      Items        : Profile_Array := (others => <>);
   end record;
end Terminal.App.Session_Profiles;
