with Terminal.Core;

private package Terminal.App.Number_Parsing is
   function Try_Natural
     (Text  : String;
      Value : out Natural) return Boolean;
   function Try_Graphics_ID
     (Text  : String;
      Value : out Terminal.Core.Graphics_ID) return Boolean;
   function Try_Integer
     (Text  : String;
      Value : out Integer) return Boolean;
end Terminal.App.Number_Parsing;
