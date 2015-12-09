//Check whether is a number or not
function isNum(args)
{
    args = args.toString();

    if (args.length == 0) return false;

    for (var i = 0;  i<args.length;  i++)
    {
        if ((args.substring(i,i+1) < "0" || args.substring(i, i+1) > "9") && args.substring(i, i+1) != "."&& args.substring(i, i+1) != "-")
        {
            return false;
        }
    }

    return true;
}

//calculate the mean of a number array
function mean(arr)
{
    var len = 0;
    var sum = 0;
    
    for(var i=0;i<arr.length;i++)
    {
          if (arr[i] == ""){}
          else if (!isNum(arr[i]))
          {
              alert(arr[i] + " is not number!");
              return;
          }
          else
          {
             len = len + 1;
             sum = sum + parseFloat(arr[i]); 
          }
    }

    return sum / len;    
}


function variance(arr)
{
    var len = 0;
    var sum=0;
    for(var i=0;i<arr.length;i++)
    {
          if (arr[i] == ""){}
          else if (!isNum(arr[i]))
          {
              alert(arr[i] + " is not number, Variance Calculation failed!");
              return 0;
          }
          else
          {
             len = len + 1;
             sum = sum + parseFloat(arr[i]); 
          }
    }

    var v = 0;
    if (len > 1)
    {
        var mean = sum / len;
        for(var i=0;i<arr.length;i++)
        {
              if (arr[i] == ""){}
              else
              {
                  v = v + (arr[i] - mean) * (arr[i] - mean);              
              }        
        }
        
        return v / len;
    }
    else
    {
         return 0;
    }    
}




//Get the largest number of a number array
function max(arr)
{
    var max = -99999;
    
    for(var i=0;i<arr.length;i++)
    {
          if (arr[i] == ""){}
          else if (!isNum(arr[i]))
          {
              alert(arr[i] + " is not number!");
              return;
          }
          else
          {
             if (i == 0) {max = arr[i];}
             else if (max < arr[i]) {max = arr[i];}
          }
    }

    return max;    
}

//Get the smallest number of a number array
function min(arr)
{
    var min = 99999;
    
    for(var i=0;i<arr.length;i++)
    {
          if (arr[i] == ""){}
          else if (!isNum(arr[i]))
          {
              alert(arr[i] + " is not number!");
              return;
          }
          else
          {
             if (i == 0) {min = arr[i];}
             else if (min > arr[i]) {min = arr[i];}
          }
    }

    return min;    
}

// //Standard deviation
// var sd = Math.sqrt(variance(arr));
// 
// //Standard error
// var se = Math.sqrt(variance(arr)/(arr.length-1));

function stdev(arr) {
  return Math.sqrt(variance(arr));
}

function median(arr)
{
    arr.sort(function(a,b){return a-b});
    
    var median = 0;
    
    if (arr.length % 2 == 1)
    {
        median = arr[(arr.length+1)/2 - 1];
    }
    else
    {
        median = (1 * arr[arr.length/2 - 1] + 1 * arr[arr.length/2] )/2;
    }
    
    return median
}

