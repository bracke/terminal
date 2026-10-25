package Terminal.App.Status_Labels is
   function Humanize (Text : String) return String;
   function Bounded
     (Text           : String;
      Maximum_Length : Positive) return String;
end Terminal.App.Status_Labels;
