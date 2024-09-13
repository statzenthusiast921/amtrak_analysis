import pandas as pd
import numpy as np
import os
import plotly.express as px
import dash
from dash import dcc, html
import dash_bootstrap_components as dbc
from dash.dependencies import Input, Output, State
from dash import dash_table

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
                       html.P("This dashboard was created as a tool to: ",style={'color':'white'}),
                       html.P("1.) Blah",style={'color':'white'}),
                       html.P("2.) Blah",style={'color':'white'}),
                       html.P("3.) Blah",style={'color':'white'}),


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
                       html.P("1.) Blah.",style={'color':'white'}),
                       html.P("2.) Blah.",style={'color':'white'})
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
        dcc.Tab(label='Page 3',value='tab-3',style=tab_style, selected_style=tab_selected_style,
            children=[
                dbc.Row([
                    dbc.Col([
                    ])
                ])
            ]
        ),
        dcc.Tab(label='Page 4',value='tab-4',style=tab_style, selected_style=tab_selected_style,
            children=[
                dbc.Row([
                    dbc.Col([
                    ])
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
        mode='lines+markers'#,
        # hovertemplate='<b>%{text}</b><br>' +
        #               '<b>Month:</b> %{x}<br>' +
        #               '<b>Rides:</b> %{y:,.0f}<br>' +  
        #               '<b>Parent Route:</b> %{color}<br>' +
        #               '<b>Year:</b> %{customdata[0]}<extra></extra>',
        # text=parent_route_filtered_df['parent_route'],
        # customdata=parent_route_filtered_df[['year']].values
    )


    return line_chart

    
if __name__=='__main__':
	app.run_server()