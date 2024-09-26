import pandas as pd
import numpy as np
import os
import plotly.express as px
import dash
from dash import dcc, html
import dash_bootstrap_components as dbc
from dash.dependencies import Input, Output, State
from dash import dash_table
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import math

#-----Read in and set up data
amtrak_df = pd.read_csv('https://raw.githubusercontent.com/statzenthusiast921/amtrak_analysis/main/data/amtrak_preds_df.csv')
amtrak_coords = pd.read_csv('https://raw.githubusercontent.com/statzenthusiast921/amtrak_analysis/main/data/amtrak_df_v2.csv')
amtrak_coords = amtrak_coords[['station_name','lat','lon']].drop_duplicates()
amtrak_df = pd.merge(amtrak_df, amtrak_coords, on='station_name', how='left')
amtrak_df = amtrak_df.rename(
    columns={
        '.key': 'key', 
        '.index': 'month_date', 
        '.value': 'rides'
    }
).drop(columns='.model_desc')

amtrak_df['month_date'] = pd.to_datetime(amtrak_df['month_date'])
amtrak_df['year'] = amtrak_df['month_date'].dt.year
amtrak_df['month'] = amtrak_df['month_date'].dt.month

#-----Set up choices for dropdown menus
bl_choices = sorted(amtrak_df['business_line'].unique())
pr_choices = sorted(amtrak_df['business_line'].unique())


#-----Business line table
business_line_table = amtrak_df.groupby(['business_line', 'year'])['rides'].sum().reset_index()
business_line_table = business_line_table.pivot(index='business_line', columns='year', values='rides')
business_line_table = business_line_table.round().reset_index().rename(
    columns = {
        'business_line':'Business Line'
    }
)

for col in business_line_table.columns[1:]:
    business_line_table[col] = pd.to_numeric(business_line_table[col], errors='coerce')

def format_millions(x):
    if pd.isna(x):
        return ''
    return f'{x / 1e6:.2f} M'

#-----Apply formatting to all columns except the first
for col in business_line_table.columns[1:]:
    business_line_table[col] = business_line_table[col].apply(format_millions)

# Business Line --> Parent Route Dictionary
df_for_dict = amtrak_df[['business_line','parent_route']]
df_for_dict = df_for_dict.drop_duplicates(subset='parent_route',keep='first')
business_line_parent_route_dict = df_for_dict.groupby('business_line')['parent_route'].apply(list).to_dict()

#----- Station Table
station_table = amtrak_df[['station_name','rides']]


#----- Define style for different pages in app
tabs_styles = {
    'height': '44px'
}
tab_style = {
    'borderBottom': '1px solid #d6d6d6',
    'padding': '6px',
    'fontWeight': 'bold',
    'color':'white',
    'backgroundColor': '#222222'

}

tab_selected_style = {
    'borderTop': '1px solid #d6d6d6',
    'borderBottom': '1px solid #d6d6d6',
    'backgroundColor': '#626ffb',
    'color': 'white',
    'padding': '6px'
}



app = dash.Dash(__name__,assets_folder=os.path.join(os.curdir,"assets"))
server = app.server
app.layout = html.Div([
    dcc.Tabs([
        dcc.Tab(label='Welcome',value='tab-1',style=tab_style, selected_style=tab_selected_style,
               children=[
                   html.Div([
                       html.H1(dcc.Markdown('''**Welcome to my Amtrak Forecast Dashboard!**''')),
                       html.Br()
                   ]),
                   
                   html.Div([
                        html.P(dcc.Markdown('''**What is the purpose of this dashboard?**'''),style={'color':'white'}),
                   ],style={'text-decoration': 'underline'}),
                   html.Div([
                       html.P("This dashboard was created as a tool to visualize the results of my grouped Amtrak ridership forecasting in multiple ways.",style={'color':'white'}),
                       html.Br()
                   ]),
                   html.Div([
                       html.P(dcc.Markdown('''**What data is being used for this analysis?**'''),style={'color':'white'}),
                   ],style={'text-decoration': 'underline'}),
                   
                   html.Div([
                       html.P(["The data utilized for this dashboard was scraped from the ",html.A('Rail Passenger Ridership Statistics.',href='https://www.railpassengers.org/resources/ridership-statistics/')],style={'color':'white'}),
                       html.Br()
                   ]),
                   html.Div([
                       html.P(dcc.Markdown('''**What are the limitations of this data?**'''),style={'color':'white'}),
                   ],style={'text-decoration': 'underline'}),
                   html.Div([
                       html.P("The data was only available at a yearly level.  I had to break the data out by month and adjust the peaks and valleys over the course in a year manually.",style={'color':'white'}),
                   ])


               ]),
        dcc.Tab(label='Ridership Forecasts',value='tab-2',style=tab_style, selected_style=tab_selected_style,
            children=[
                dbc.Row([
                    dbc.Col([
                        html.Label(dcc.Markdown('''**Select a business line: **'''),style={'color':'white'}),                        
                        dcc.Dropdown(
                            id='dropdown1',
                            style={'color':'black'},
                            options=[{'label': i, 'value': i} for i in bl_choices],
                            value=bl_choices[0]
                        ),
                        dash_table.DataTable(
                            id='business_line_table',
                            columns=[{"name": i, "id": i} for i in business_line_table.columns],
                            data=business_line_table.to_dict('records'),
                            style_table={
                                'overflowX': 'auto',
                                'backgroundColor': '#000000' 
                            },
                            style_cell={
                                'textAlign': 'left',
                                'color': '#FFFFFF',  
                                'backgroundColor': '#000000',  
                            },
                            style_header={
                                'backgroundColor': '#333333', 
                                'color': '#FFFFFF',  
                                'fontWeight': 'bold'
                            },
                            style_data_conditional=[
                                {
                                    'if': {
                                        'column_id': [2023, 2024]
                                    },
                                    'backgroundColor': '#ff4d4d', 
                                    'color': 'white'
                                }
                            ]
                        ),
                        html.Label([
                            html.Span('Actuals = Black', style={'color': 'grey'}),
                            ' | ', 
                            html.Span('Forecasts = Red', style={'color': '#ff4d4d'})
                        ]),
                        html.Br(),
                        html.Label(dcc.Markdown('''**Select a year: **'''),style={'color':'white'}),                        
                        dcc.Slider(
                            id='slider1',
                            min=amtrak_df['year'].min(),
                            max=amtrak_df['year'].max(),
                            step=1,
                            marks={year: str(year) for year in list(range(2016, 2025))},

                            value=amtrak_df['year'].min()
                        ),
                        dcc.Graph(id = 'parent_route_monthly_charts')
                    ])
                ])
            ]
        ),
        dcc.Tab(label='Station Details',value='tab-3',style=tab_style, selected_style=tab_selected_style,
            children=[
                dbc.Row([
                    dbc.Col([
                        html.Label(dcc.Markdown('''**Select a business line: **'''),style={'color':'white'}),                        
                        dcc.Dropdown(
                            id='dropdown2',
                            style={'color':'black'},
                            options=[{'label': i, 'value': i} for i in bl_choices],
                            value=bl_choices[0]
                        )
                    ], width =6),
                    dbc.Col([
                        html.Label(dcc.Markdown('''**Select a parent route: **'''),style={'color':'white'}),                        
                        dcc.Dropdown(
                            id='dropdown3',
                            style={'color':'black'},
                            options=[{'label': i, 'value': i} for i in pr_choices],
                            value=pr_choices[0]
                        )
                    ], width = 6),
                    dbc.Col([
                        dcc.Graph(id = 'stn_fc_charts')
                    ])
                ])
            ]
        ),
        dcc.Tab(label='Map',value='tab-4',style=tab_style, selected_style=tab_selected_style,
            children=[
                dbc.Row([
                    dbc.Col([
                        html.Label(dcc.Markdown('''**Select a business line: **'''),style={'color':'white'}),                        
                        dcc.Dropdown(
                            id='dropdown4',
                            style={'color':'black'},
                            options=[{'label': i, 'value': i} for i in bl_choices],
                            value=bl_choices[0]
                        )
                    ], width =6),
                    dbc.Col([
                        html.Label(dcc.Markdown('''**Select a parent route: **'''),style={'color':'white'}),                        
                        dcc.Dropdown(
                            id='dropdown5',
                            style={'color':'black'},
                            options=[{'label': i, 'value': i} for i in pr_choices],
                            value=pr_choices[0]
                        )
                    ], width =6),
                    dbc.Col([
                        dcc.Slider(
                            id='slider2',
                            min=amtrak_df['year'].min(),
                            max=amtrak_df['year'].max(),
                            step=1,
                            marks={year: str(year) for year in list(range(2016, 2025))},

                            value=amtrak_df['year'].min()
                        ),
                    ], width = 12),
                    dbc.Col([
                        dcc.Graph(id='route_map')
                    ], width = 6),
                    dbc.Col([
                        dash_table.DataTable(
                            id='station_table',
                            columns=[{"name": i, "id": i} for i in station_table.columns],
                            data=station_table.to_dict('records'),
                            style_table={
                                'overflowX': 'auto',
                                'overflowY': 'auto',
                                'backgroundColor': '#000000' ,
                                'maxHeight': '450px'

                            }
                        )
                    ], width = 6)

                ])
            ]
        )
    ])
])

#Tab #1: FC Table --> Business Line
@app.callback(
    Output('business_line_table','data'),
    Input('dropdown1','value')
)
def bl_fc_table(dd1):
    bl_table_filtered = business_line_table[(business_line_table['Business Line']==dd1)]

    return bl_table_filtered.to_dict('records')


#Tab #1: Top 5 Parent Routes Monthly Chart by Year 
@app.callback(
    Output('parent_route_monthly_charts','figure'),
    Input('dropdown1','value'),
    Input('slider1','value'),

)
def monthly_chart_parent_routes(dd1, slider1):
    parent_route = amtrak_df[amtrak_df['business_line']==dd1]
    top5_parent_routes = parent_route.groupby(['parent_route'])['rides'].sum().reset_index()
    top5_parent_routes = top5_parent_routes.sort_values(by = 'rides',ascending=False).head(5)
    top5_parent_routes_list = top5_parent_routes['parent_route'].unique()
    parent_route_df = amtrak_df[amtrak_df['parent_route'].isin(top5_parent_routes_list)]
    parent_route_df = parent_route_df.groupby(['parent_route','year','month'])['rides'].sum().reset_index()
    parent_route_filtered_df = parent_route_df[parent_route_df['year']==slider1]
    
    val1 = parent_route['business_line'].unique()[0]
    val2 = slider1

    line_chart = px.line(
        parent_route_filtered_df,
        x = 'month',
        y = 'rides',
        color = 'parent_route',
        hover_data={
            'month': True,  
            'rides': ':,.0f', 
            'parent_route': True,  
            'year': True 
        },
        labels={
            'month':'Month',
            'rides':'Rides',
            'parent_route':'Parent Route',
            'year':'Year'
        },
        title = f'Monthly Ridership Actuals for Top 5 Parent Routes of the {val1} business line in {val2}'

    ).update_layout(
        xaxis_title='Month', 
        yaxis_title='Rides' ,
        template='plotly_dark',
        legend_title='Parent Route'

    )

    #-----Check if the selected year is 2023 or 2024
    if slider1 in [2023, 2024]:
        #-----Update line style to dashed for the selected years
        line_chart.update_traces(line=dict(dash='dash'))
        #-----Update title to 'Forecasts' for these years
        line_chart.update_layout(title = f'Monthly Ridership Forecasts for Top 5 Parent Routes of the {val1} business line in {val2}')

    # Create a mapping of month numbers to month names
    month_names = {
        1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'May', 6: 'Jun',
        7: 'Jul', 8: 'Aug', 9: 'Sep', 10: 'Oct', 11: 'Nov', 12: 'Dec'
    }

    # Update the x-axis with month names
    line_chart.update_xaxes(
        tickvals=list(month_names.keys()),  # Ensure these values match your x data
        ticktext=[month_names[i] for i in month_names.keys()]  # Use month names
    ).update_traces(
        mode='lines+markers'
    ).add_annotation(
        x=2.5,  
        y=parent_route_filtered_df['rides'].max(),  
        text="Solid = Actuals | Dashed = Forecast",  
        showarrow=False,  
        xref="x", 
        yref="y", 
        font=dict(
            size=12,
            color="white"
        ),
        align="center",
        bgcolor="rgba(0,0,0,0.5)",  # Semi-transparent background for better visibility
        bordercolor="white"
    )

    return line_chart

@app.callback(
    Output('dropdown3', 'options'), #--> filter parent route
    Output('dropdown3', 'value'),
    Input('dropdown2', 'value') #--> choose business line
)
def set_parent_route_ptions(selected_business_line):
    if selected_business_line in business_line_parent_route_dict:
        return [{'label': i, 'value': i} for i in business_line_parent_route_dict[selected_business_line]], business_line_parent_route_dict[selected_business_line][0]
    else:
        return [], None


@app.callback(
    Output('dropdown5', 'options'), #--> filter parent route
    Output('dropdown5', 'value'),
    Input('dropdown4', 'value') #--> choose business line
)
def set_parent_route_ptions(selected_business_line):
    if selected_business_line in business_line_parent_route_dict:
        return [{'label': i, 'value': i} for i in business_line_parent_route_dict[selected_business_line]], business_line_parent_route_dict[selected_business_line][0]
    else:
        return [], None


@app.callback(
    Output('stn_fc_charts', 'figure'),  #--> filter parent route
    Input('dropdown3', 'value')  #--> choose business line
)
def stn_fc_chart_many(dd3):
    filtered_df = amtrak_df[amtrak_df['parent_route'] == dd3]
    
    stn_rides_df = filtered_df.groupby(['station_name', 'month_date', 'key'])['rides'].sum().reset_index()

    # Number of unique station names
    station_names = stn_rides_df['station_name'].unique()
    num_stations = len(station_names)

    # Create a color map for the keys
    unique_keys = stn_rides_df['key'].unique()
    colors = px.colors.qualitative.Plotly  # Choose a color palette
    color_map = {key: colors[i % len(colors)] for i, key in enumerate(unique_keys)}

    # Set a maximum number of columns and rows for subplots
    max_columns = 4
    num_columns = min(max_columns, int(num_stations ** 0.5))
    num_rows = (num_stations + num_columns - 1) // num_columns  # Ceiling division

    # Set a fixed height for each subplot
    subplot_height = 200  # Adjust this value as needed
    total_height = subplot_height * num_rows

    # Create a subplot figure
    fig = make_subplots(rows=num_rows, cols=num_columns, subplot_titles=station_names, vertical_spacing=0.1)

    # Create traces for each station
    for i, station in enumerate(station_names):
        station_data = stn_rides_df[stn_rides_df['station_name'] == station]
        
        # Get row and column for the subplot
        row = i // num_columns + 1
        col = i % num_columns + 1
        
        # Add a trace for each key within the station
        for key in station_data['key'].unique():
            key_data = station_data[station_data['key'] == key]
            line_color = color_map[key]

            # Determine the name based on whether it's actual or forecast
            if key == 'actual_key_identifier':  # Replace with the actual identifier for actuals
                trace_name = 'Actual'
            elif key == 'forecast_key_identifier':  # Replace with the actual identifier for forecasts
                trace_name = 'Forecast'
            else:
                trace_name = ""  # Skip adding a name for any other key
            
            # Add trace
            fig.add_trace(
                go.Scatter(
                    x=key_data['month_date'],
                    y=key_data['rides'],
                    mode='lines+markers',
                    hovertemplate='Station: ' + station + '<br>Rides: %{y}<br>Mon-Yr: %{x}<br>Key: %{customdata}<extra></extra>',

                    customdata=[key] * len(key_data),  # Pass the key value as customdata
                    name=trace_name,
                    line=dict(color=line_color)
                ),
                row=row,
                col=col
            )

    # Update layout and axes
    fig.update_layout(
        title_text=f"Ridership Trends for {dd3} Parent Route",
        title_x=0.5,
        #height=800,
        height=total_height,  # Use the total height calculated

        showlegend=False
    )

    # Hide x-axis labels
    fig.update_xaxes(title_text=None)

    return fig


#----- Tab 4: Map of Routes
@app.callback(
    Output('route_map','figure'),
    Input('dropdown4','value'),
    Input('dropdown5','value'),
    Input('slider2', 'value')

)
def route_map(dd4, dd5, slider2):

    filtered1 = amtrak_df[amtrak_df['business_line']==dd4]
    filtered2 = filtered1[filtered1['parent_route']==dd5]
    filtered3 = filtered2[filtered2['year']==slider2]

    df_for_plot = filtered3.groupby(['business_line','parent_route','station_name','year','lat','lon'])['rides'].sum().reset_index()



    fig = px.scatter_mapbox(
        df_for_plot, 
        lat="lat", lon="lon", 
        hover_name="station_name", 
        color="rides",
        size = "rides",
        zoom=4,
        mapbox_style="carto-positron",
        hover_data={
            'business_line': True,
            'parent_route' : True,
            'station_name' : True,
            'year': True ,
            'rides': ':,.0f', 
            'lat': False,  
            'lon': False
 
        },
        labels={
            'business_line':'Business Line',
            'parent_route':'Parent Route',
            'station_name':'Station Name',
            'year':'Year',
            'rides':'Rides'
        },

    )
    return fig


@app.callback(
    Output('station_table','data'),
    Input('dropdown4','value'),
    Input('dropdown5','value'),
    Input('slider2', 'value')

)
def update_station_table(dd4, dd5, slider2):

    filtered_df = amtrak_df[
        (amtrak_df['business_line'] == dd4) &
        (amtrak_df['parent_route'] == dd5) &
        (amtrak_df['year'] == slider2)
    ]

    table_final = filtered_df[['station_name','rides']]
    table_final = table_final.groupby(['station_name'])['rides'].sum().reset_index()
    table_final = table_final.sort_values(by = 'rides', ascending = False)



    return table_final.to_dict('records')

if __name__=='__main__':
	app.run_server()