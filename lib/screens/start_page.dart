import 'package:flutter/material.dart';
import 'package:flutter_projects/screens/connection_screen.dart';



class HomePage extends StatelessWidget{
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight=MediaQuery.of(context).size.height;
    final screenWidth=MediaQuery.of(context).size.width;
    return
      SafeArea(
        child: Scaffold(
            backgroundColor: Colors.white, //Color(0xFFF0F4FF),
            body:Padding(
              padding:  EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child:FittedBox(
                      fit: BoxFit.contain,
                      child: Image.asset(
                        'assets/LogoDRD.png',
                        height: 80,
                        fit: BoxFit.contain,
                      ) ,
                    ),
                  ),
                   SizedBox(height: screenHeight * 0.03),
                  const Text('Connect to Your EC-1 Device to begin.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                   SizedBox(height: screenHeight * 0.04),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:[Color(0xFF1976D2),Color(0xFF2196F3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ElevatedButton(onPressed: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=> const ConnectionScreen()),);
                    },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01,vertical: screenHeight * 0.02),
                          textStyle: TextStyle(fontSize: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          )
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children:const [
                          Icon(
                            Icons.bluetooth,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10,),
                          Text(
                            'Start connection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Spacer(flex: 1),
                  const Text(
                    'Powered by DRD Automation GmbH',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                   SizedBox(height: screenHeight * 0.015),
                ],
              ),


            )
        ),
      );
  }
}


