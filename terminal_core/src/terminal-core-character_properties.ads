with Terminal.Common;

private package Terminal.Core.Character_Properties is
   function Is_Wide (CP : Common.Code_Point) return Boolean;
   function Is_Emoji_Variation_Base
     (CP : Common.Code_Point) return Boolean;
   function Is_Keycap_Base (CP : Common.Code_Point) return Boolean;
   function Is_Regional_Indicator
     (CP : Common.Code_Point) return Boolean;
   function Is_Emoji_Modifier
     (CP : Common.Code_Point) return Boolean;
   function Is_Zero_Width (CP : Common.Code_Point) return Boolean;
   function Is_Renderable_Attachment
     (CP : Common.Code_Point) return Boolean;
end Terminal.Core.Character_Properties;
