with Terminal.App.Session_Profiles;

package Terminal.App.Session_Profile_Discovery is
   procedure Discover_SSH
     (Profiles : in out Terminal.App.Session_Profiles.Registry;
      Path     : String;
      Added    : out Natural);
end Terminal.App.Session_Profile_Discovery;
